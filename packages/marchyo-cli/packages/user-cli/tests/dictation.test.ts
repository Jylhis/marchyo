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

type Script = Record<string, Probe>;

function deps(backend: Backend | null, script: Script, installed = true): DictationDeps {
  return {
    backend: () => backend,
    run: async (argv) => {
      calls.push(argv);
      return script[argv.join(" ")] ?? { code: 0, stdout: "" };
    },
    available: () => installed,
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

const VOXTYPE_RECORDING = { code: 0, stdout: '{"class":"recording"}' };

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "marchyo-dictation-"));
  calls = [];
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

test("the baked backend is read from the config file", () => {
  const path = join(dir, "dictation.json");
  writeFileSync(path, JSON.stringify({ backend: "voxtype" }));
  expect(bakedBackend(path)).toBe("voxtype");
  writeFileSync(path, JSON.stringify({ backend: "superwhisper" }));
  expect(bakedBackend(path)).toBeNull();
  expect(bakedBackend(join(dir, "missing.json"))).toBeNull();
});

test("an unknown action is a usage error", async () => {
  const { code } = await captured(() => runDictation(RT, "pause", deps("voxtype", {})));
  expect(code).toBe(2);
  expect(calls).toEqual([]);
});

test("no configured backend fails", async () => {
  const { code, out } = await captured(() => runDictation(RT, "toggle", deps(null, {})));
  expect(code).toBe(1);
  expect(out).toContain("no dictation backend");
});

test("a missing backend binary fails", async () => {
  const { code, out } = await captured(() => runDictation(RT, "start", deps("voxtype", {}, false)));
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

test("status reports the normalised state as JSON", async () => {
  const { code, out } = await captured(() =>
    runDictation(JSON_RT, "status", deps("voxtype", { "voxtype status --format json": VOXTYPE_RECORDING })),
  );
  expect(code).toBe(0);
  expect(JSON.parse(out)).toEqual({ dictation: { backend: "voxtype", state: "recording" } });
});

test("status is stopped when the backend does not answer", async () => {
  const d = deps("voxtype", { "voxtype status --format json": { code: 1, stdout: "" } });
  const { out } = await captured(() => runDictation(RT, "status", d));
  expect(out.trim()).toBe("stopped");
});

test("a held lock makes a concurrent call fail", async () => {
  writeFileSync(join(dir, "dictation.lock"), String(process.pid));
  const { code, out } = await captured(() => runDictation(RT, "toggle", deps("voxtype", {})));
  expect(code).toBe(1);
  expect(out).toContain("busy");
});

test("a stale lock from a dead process is reclaimed", async () => {
  writeFileSync(join(dir, "dictation.lock"), "999999999");
  const { code } = await captured(() => runDictation(RT, "start", deps("voxtype", {})));
  expect(code).toBe(0);
});
