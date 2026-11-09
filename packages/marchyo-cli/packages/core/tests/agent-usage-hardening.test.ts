import { expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import {
  ENDPOINTS,
  MAX_LINE_CHARS,
  ProbeError,
  codexRpc,
  collectUsage,
  fileLines,
  getJson,
  readUsageFile,
  usageDir,
} from "../src/agent-usage.ts";
import { fakeHome } from "./agent-usage-fixture.ts";

const NOW = Date.parse("2026-11-05T12:00:00Z");

function alive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// An app-server that answers, then ignores SIGTERM and stdin EOF.
function stubbornCodex(dir: string, pidFile: string, flood = false): string {
  const bin = join(dir, "codex-stubborn");
  writeFileSync(
    bin,
    `#!${process.execPath}
require("node:fs").writeFileSync(${JSON.stringify(pidFile)}, String(process.pid));
process.on("SIGTERM", () => {});
setInterval(() => {}, 1000);
const out = (o) => process.stdout.write(JSON.stringify(o) + "\\n");
if (${flood}) process.stdout.write("x".repeat(3_000_000));
let buf = "";
for await (const chunk of Bun.stdin.stream()) {
  buf += new TextDecoder().decode(chunk);
  let i;
  while ((i = buf.indexOf("\\n")) >= 0) {
    const msg = JSON.parse(buf.slice(0, i));
    buf = buf.slice(i + 1);
    if (msg.id !== undefined) out({ id: msg.id, result: { rateLimits: {} } });
  }
}
`,
  );
  chmodSync(bin, 0o755);
  return bin;
}

test("the Codex app-server is killed and reaped even when it ignores SIGTERM", async () => {
  const fh = fakeHome(NOW);
  const pidFile = join(fh.home, "pid");
  const reply = await codexRpc(stubbornCodex(fh.home, pidFile), fh.deps.env);
  expect(reply).toEqual({ id: 2, result: { rateLimits: {} } });
  expect(alive(Number(readFileSync(pidFile, "utf8")))).toBe(false);
});

test("an app-server line without end is refused once it passes the cap", async () => {
  const fh = fakeHome(NOW);
  const pidFile = join(fh.home, "pid");
  await expect(codexRpc(stubbornCodex(fh.home, pidFile, true), fh.deps.env)).rejects.toThrow(
    "answered too much",
  );
  expect(alive(Number(readFileSync(pidFile, "utf8")))).toBe(false);
});

test("an HTTP body over the cap is refused while it streams", async () => {
  const fh = fakeHome(NOW);
  const chunk = new Uint8Array(512 * 1024).fill(32);
  let sent = 0;
  const body = new ReadableStream<Uint8Array>({
    pull(c) {
      sent += chunk.byteLength;
      if (sent > 8 * 1024 * 1024) c.close();
      else c.enqueue(chunk);
    },
  });
  const deps = { ...fh.deps, fetch: async () => new Response(body) };
  await expect(getJson(deps, ENDPOINTS.claude, {})).rejects.toThrow(ProbeError);
  expect(sent).toBeLessThan(4 * 1024 * 1024);
  const declared = { ...fh.deps, fetch: async () => new Response("{}", { headers: { "content-length": "9000000" } }) };
  await expect(getJson(declared, ENDPOINTS.claude, {})).rejects.toThrow("answered too much");
});

test("fileLines streams lines and drops one longer than the cap", () => {
  const fh = fakeHome(NOW);
  const path = join(fh.home, "t.jsonl");
  writeFileSync(path, `a\n${"x".repeat(MAX_LINE_CHARS + 10)}\nb\nc`);
  expect([...fileLines(path)]).toEqual(["a", "b", "c"]);
  const link = join(fh.home, "link.jsonl");
  symlinkSync(path, link);
  expect(() => [...fileLines(link)]).toThrow();
});

test("a group-writable state dir is tightened; a symlinked one is refused softly", async () => {
  const fh = fakeHome(NOW);
  const dir = usageDir(fh.deps.env, fh.home);
  mkdirSync(dir, { recursive: true });
  chmodSync(dir, 0o777);
  await collectUsage(fh.deps);
  expect(statSync(dir).mode & 0o777).toBe(0o700);
  expect(readdirSync(dir).filter((f) => f.endsWith(".tmp"))).toEqual([]);

  const other = fakeHome(NOW);
  const target = join(other.home, "elsewhere");
  mkdirSync(target);
  const linked = usageDir(other.deps.env, other.home);
  mkdirSync(join(linked, ".."), { recursive: true });
  symlinkSync(target, linked);
  const file = await collectUsage(other.deps);
  expect(file.stateError).toContain("not a directory");
  expect(file.agents.find((a) => a.id === "claude")!.limits).toHaveLength(3);
  expect(readdirSync(target)).toEqual([]);
});

test("a symlinked usage.json is replaced, never written through", async () => {
  const fh = fakeHome(NOW);
  const dir = usageDir(fh.deps.env, fh.home);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const victim = join(fh.home, "victim");
  writeFileSync(victim, "keep");
  symlinkSync(victim, join(dir, "usage.json"));
  await collectUsage(fh.deps);
  expect(readFileSync(victim, "utf8")).toBe("keep");
  expect(lstatSync(join(dir, "usage.json")).isSymbolicLink()).toBe(false);
});

test("bad entries in usage.json and scan-index.json are dropped, not thrown", async () => {
  const fh = fakeHome(NOW);
  const dir = usageDir(fh.deps.env, fh.home);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const goodProbe = { at: NOW, ready: true, limits: [{ label: "L", percent: 0.5, resetsAt: "" }], fetchedAt: NOW };
  const day = { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, total: 2, cost: 0 };
  writeFileSync(
    join(dir, "usage.json"),
    JSON.stringify({
      schemaVersion: 1,
      updatedAt: 5,
      agents: [{ id: "claude", name: "x", ready: true, limits: [], limitsFetchedAt: 0 }, { id: "evil" }],
      scannedAt: "soon",
      probes: { claude: goodProbe, codex: { at: "x" }, toString: goodProbe, copilot: { ...goodProbe, limits: [{ percent: 9 }] } },
      scans: { claude: { "2026-11-05": day, "../x": day, "2026-11-04": { input: -1 } }, other: {} },
    }),
  );
  const prev = readUsageFile(join(dir, "usage.json"));
  expect(prev.agents).toHaveLength(1);
  expect(Object.keys(prev.probes)).toEqual(["claude"]);
  expect(Object.keys(prev.scans)).toEqual(["claude"]);
  expect(Object.keys(prev.scans.claude!)).toEqual(["2026-11-05"]);
  expect(prev.scannedAt).toBe(0);
  expect(prev.updatedAt).toBe("");

  writeFileSync(join(dir, "scan-index.json"), JSON.stringify({ "/x": { size: "big" }, "/y": 3, "/z": { size: 1, mtimeMs: 1, days: { bad: 1 } } }));
  const file = await collectUsage({ ...fh.deps, now: () => NOW + 1 });
  expect(file.agents).toHaveLength(6);
  writeFileSync(join(dir, "usage.json"), "{not json");
  expect(readUsageFile(join(dir, "usage.json")).agents).toEqual([]);
  expect(existsSync(join(dir, "scan-index.json"))).toBe(true);
});
