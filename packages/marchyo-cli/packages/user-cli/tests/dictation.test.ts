import { afterEach, beforeEach, expect, spyOn, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Runtime } from "@marchyo/core";
import {
  type Backend,
  type DictationDeps,
  type Probe,
  bakedBackend,
  runDictation,
} from "../src/commands/dictation.ts";

const RT: Runtime = {
  format: "text",
  noColor: true,
  forceColor: false,
  plain: true,
  noAnimation: true,
  noInput: true,
  quiet: false,
  verbose: 0,
};
const JSON_RT: Runtime = { ...RT, format: "json" };

let dir = "";
let calls: string[][] = [];
let pasted: string[] = [];

type Script = Record<string, Probe>;

function deps(backend: Backend | null, script: Script, installed = true): DictationDeps {
  return {
    backend: () => backend,
    run: async (argv) => {
      calls.push(argv);
      return script[argv.join(" ")] ?? { code: 0, stdout: "" };
    },
    available: () => installed,
    paste: async (text) => {
      pasted.push(text);
    },
    lockPath: join(dir, "dictation.lock"),
    lockWaitMs: 200,
  };
}

async function captured(fn: () => Promise<number>): Promise<{ code: number; out: string }> {
  const chunks: string[] = [];
  const grab = (c: string | Uint8Array): boolean => {
    chunks.push(String(c));
    return true;
  };
  const so = spyOn(process.stdout, "write").mockImplementation(grab);
  const se = spyOn(process.stderr, "write").mockImplementation(grab);
  try {
    const code = await fn();
    return { code, out: chunks.join("") };
  } finally {
    so.mockRestore();
    se.mockRestore();
  }
}

const joined = () => calls.map((c) => c.join(" "));

const HEX_DICTATING = { code: 0, stdout: '{"desktop":{"activity":{"state":"dictating"}}}' };
const HEX_IDLE = { code: 0, stdout: '{"desktop":{"activity":{"state":"idle"}}}' };

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "marchyo-dictation-"));
  calls = [];
  pasted = [];
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

test("the baked backend is read from the config file", () => {
  const path = join(dir, "dictation.json");
  writeFileSync(path, JSON.stringify({ backend: "hex" }));
  expect(bakedBackend(path)).toBe("hex");
  writeFileSync(path, JSON.stringify({ backend: "bogus" }));
  expect(bakedBackend(path)).toBeNull();
  expect(bakedBackend(join(dir, "missing.json"))).toBeNull();
});

test("an unknown action is a usage error", async () => {
  const { code } = await captured(() => runDictation(RT, "pause", deps("hex", {})));
  expect(code).toBe(2);
  expect(calls).toEqual([]);
});

test("no configured backend fails", async () => {
  const { code, out } = await captured(() => runDictation(RT, "toggle", deps(null, {})));
  expect(code).toBe(1);
  expect(out).toContain("no dictation backend");
});

test("a missing backend binary fails", async () => {
  const { code, out } = await captured(() => runDictation(RT, "start", deps("hex", {}, false)));
  expect(code).toBe(1);
  expect(out).toContain("not installed");
});

test("voxtype start, stop and toggle map to voxtype record", async () => {
  const d = deps("voxtype", {
    "voxtype status --format json": { code: 0, stdout: '{"class":"recording"}' },
  });
  await captured(() => runDictation(RT, "start", d));
  await captured(() => runDictation(RT, "toggle", d));
  await captured(() => runDictation(RT, "stop", d));
  expect(joined()).toContain("voxtype record start");
  expect(joined()).toContain("voxtype record toggle");
  expect(joined()).toContain("voxtype record stop");
});

test("voxtype stop is a no-op when the daemon is not running", async () => {
  const d = deps("voxtype", { "voxtype status --format json": { code: 1, stdout: "" } });
  const { code } = await captured(() => runDictation(RT, "stop", d));
  expect(code).toBe(0);
  expect(joined()).not.toContain("voxtype record stop");
});

test("superwhisper start records, toggle uses record, stop skips an inactive service", async () => {
  const d = deps("superwhisper", {
    "systemctl --user is-active --quiet superwhisper.service": { code: 3, stdout: "" },
  });
  await captured(() => runDictation(RT, "start", d));
  await captured(() => runDictation(RT, "toggle", d));
  await captured(() => runDictation(RT, "stop", d));
  expect(joined()).toContain("superwhisper start");
  expect(joined()).toContain("superwhisper record");
  expect(joined()).not.toContain("superwhisper stop");
});

test("superwhisper stop runs when the service is active", async () => {
  await captured(() => runDictation(RT, "stop", deps("superwhisper", {})));
  expect(joined()).toContain("superwhisper stop");
});

test("hex start launches Hex when it is not running", async () => {
  let started = false;
  const d: DictationDeps = {
    ...deps("hex", {}),
    run: async (argv) => {
      calls.push(argv);
      const cmd = argv.join(" ");
      if (cmd === "hex start") started = true;
      if (cmd === "hex dictation start" && !started) return { code: 3, stdout: "" };
      return { code: 0, stdout: "" };
    },
  };
  const { code } = await captured(() => runDictation(RT, "start", d));
  expect(code).toBe(0);
  expect(joined()).toEqual(["hex dictation start", "hex start", "hex dictation start"]);
});

test("hex stop pastes the printed transcript", async () => {
  const d = deps("hex", {
    "hex status": HEX_DICTATING,
    "hex dictation stop --print": { code: 0, stdout: "hello world\n" },
  });
  const { code } = await captured(() => runDictation(RT, "stop", d));
  expect(code).toBe(0);
  expect(pasted).toEqual(["hello world"]);
});

test("hex stop does nothing when not dictating", async () => {
  await captured(() => runDictation(RT, "stop", deps("hex", { "hex status": HEX_IDLE })));
  expect(joined()).toEqual(["hex status"]);
});

test("hex stop treats no speech as success and pastes nothing", async () => {
  const d = deps("hex", {
    "hex status": HEX_DICTATING,
    "hex dictation stop --print": { code: 4, stdout: "" },
  });
  const { code } = await captured(() => runDictation(RT, "stop", d));
  expect(code).toBe(0);
  expect(pasted).toEqual([]);
});

test("hex toggle stops while dictating and starts otherwise", async () => {
  const live = deps("hex", {
    "hex status": HEX_DICTATING,
    "hex dictation stop --print": { code: 0, stdout: "x" },
  });
  await captured(() => runDictation(RT, "toggle", live));
  expect(joined()).toContain("hex dictation stop --print");

  calls = [];
  await captured(() => runDictation(RT, "toggle", deps("hex", { "hex status": HEX_IDLE })));
  expect(joined()).toContain("hex dictation start");
});

test("status reports the normalised state as JSON", async () => {
  const { code, out } = await captured(() =>
    runDictation(JSON_RT, "status", deps("hex", { "hex status": HEX_DICTATING })),
  );
  expect(code).toBe(0);
  expect(JSON.parse(out)).toEqual({ dictation: { backend: "hex", state: "recording" } });
});

test("status is stopped when the backend does not answer", async () => {
  const d = deps("superwhisper", { "superwhisper status": { code: 1, stdout: "" } });
  const { out } = await captured(() => runDictation(RT, "status", d));
  expect(out.trim()).toBe("stopped");
});

test("a held lock makes a concurrent call fail", async () => {
  writeFileSync(join(dir, "dictation.lock"), String(process.pid));
  const { code, out } = await captured(() => runDictation(RT, "toggle", deps("hex", {})));
  expect(code).toBe(1);
  expect(out).toContain("busy");
});

test("a stale lock from a dead process is reclaimed", async () => {
  writeFileSync(join(dir, "dictation.lock"), "999999999");
  const { code } = await captured(() => runDictation(RT, "start", deps("voxtype", {})));
  expect(code).toBe(0);
});
