import { afterAll, beforeAll, expect, spyOn, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type PluginLock, type Runtime, type State, PLUGIN_KINDS } from "@marchyo/core";
import { checkPluginLock } from "../src/commands/doctor.ts";
import {
  type PluginPrefetch,
  pendingPlugins,
  runPluginAdd,
  runPluginList,
  runPluginRemove,
  runPluginUpdate,
  validateManifest,
} from "../src/commands/plugin.ts";

// Quiet, non-interactive runtime so the commands never prompt or emit noise.
const rt: Runtime = {
  format: "text",
  noColor: true,
  forceColor: false,
  plain: false,
  noAnimation: true,
  noInput: true,
  quiet: true,
  verbose: 0,
};

// A prefetch stub pointing at a temp tree with a manifest.json, so add() never
// touches the network. rev/hash are arbitrary; dry-run never fetches for real.
function stubPrefetch(treePath: string): PluginPrefetch {
  return async () => ({
    rev: "0123456789abcdef0123456789abcdef01234567",
    hash: "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    path: treePath,
  });
}

let dir: string;
let manifestTree: string;
let emptyTree: string;

beforeAll(() => {
  dir = mkdtempSync(join(tmpdir(), "marchyo-plugin-test-"));
  manifestTree = join(dir, "with-manifest");
  emptyTree = join(dir, "no-manifest");
  Bun.write(join(manifestTree, ".keep"), "");
  Bun.write(join(emptyTree, ".keep"), "");
  // Isolate user state to the temp dir so list/remove see no ambient plugins.
  process.env.XDG_CONFIG_HOME = join(dir, "config");
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

function writeManifest(id: string): void {
  writeFileSync(
    join(manifestTree, "manifest.json"),
    JSON.stringify({
      schemaVersion: 1,
      id,
      name: "Example",
      version: "1",
      kinds: ["bar-widget"],
      entryPoints: { barWidget: "Panel.qml" },
    }),
  );
}

test("add rejects the reserved marchyo.* namespace", async () => {
  writeManifest("marchyo.evil");
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: stubPrefetch(manifestTree),
  });
  expect(code).toBe(1);
});

test("add rejects a source with no manifest.json", async () => {
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: stubPrefetch(emptyTree),
  });
  expect(code).toBe(1);
});

test("add fails cleanly when the prefetch cannot resolve the source", async () => {
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: async () => null,
  });
  expect(code).toBe(1);
});

test("add accepts a valid non-reserved plugin (dry run, no rebuild)", async () => {
  writeManifest("example.hello");
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: stubPrefetch(manifestTree),
  });
  expect(code).toBe(0);
});

test("list on empty state exits 0", async () => {
  const code = await runPluginList(rt, { lock: null });
  expect(code).toBe(0);
});

test("remove of an unknown plugin exits 1", async () => {
  const code = await runPluginRemove(rt, "nobody.here", { dryRun: true });
  expect(code).toBe(1);
});

// ── manifest kinds, entry points and prefix ─────────────────────────────────

const base = { schemaVersion: 1, id: "example.x" };

test("kind map is the closed bar-widget/launcher/daemon set", () => {
  expect(PLUGIN_KINDS).toEqual({
    "bar-widget": "barWidget",
    launcher: "launcher",
    daemon: "daemon",
  });
});

test("manifest with an unknown kind is rejected", () => {
  const r = validateManifest({ ...base, kinds: ["panel"], entryPoints: { panel: "P.qml" } });
  expect(r).toContain("unknown plugin kind 'panel'");
});

test("manifest missing the entry point for a kind is rejected", () => {
  const r = validateManifest({
    ...base,
    kinds: ["bar-widget", "daemon"],
    entryPoints: { barWidget: "W.qml" },
  });
  expect(r).toBe("kind 'daemon' needs entryPoints.daemon");
});

test("manifest with an entry point for an undeclared kind is rejected", () => {
  const r = validateManifest({
    ...base,
    kinds: ["daemon"],
    entryPoints: { daemon: "D.qml", barWidget: "W.qml" },
  });
  expect(r).toContain("entryPoints.barWidget matches no declared kind");
});

test("launcher manifest without a prefix is rejected", () => {
  const r = validateManifest({ ...base, kinds: ["launcher"], entryPoints: { launcher: "L.qml" } });
  expect(r).toBe("kind 'launcher' needs a non-empty prefix");
});

test("launcher prefix starting with a first-party prefix is rejected", () => {
  for (const prefix of ["=", ">x", "#w", "!"]) {
    const r = validateManifest({
      ...base,
      kinds: ["launcher"],
      entryPoints: { launcher: "L.qml" },
      prefix,
    });
    expect(r).toContain("reserved for the built-in launcher prefixes");
  }
});

test("prefix on a non-launcher plugin is rejected", () => {
  const r = validateManifest({
    ...base,
    kinds: ["daemon"],
    entryPoints: { daemon: "D.qml" },
    prefix: "?",
  });
  expect(r).toBe("manifest prefix only applies to the 'launcher' kind");
});

test("valid launcher + daemon manifest keeps its prefix", () => {
  const r = validateManifest({
    ...base,
    kinds: ["launcher", "daemon"],
    entryPoints: { launcher: "L.qml", daemon: "D.qml" },
    prefix: "?",
  });
  expect(typeof r).toBe("object");
  expect(r).toMatchObject({ prefix: "?", kinds: ["launcher", "daemon"] });
});

// ── list, update and doctor against state + a fake lock ─────────────────────

const OLD_REV = "1111111111111111111111111111111111111111";
const NEW_REV = "2222222222222222222222222222222222222222";
const HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

type Extra = NonNullable<NonNullable<State["shell"]>["extraPlugins"]>[number];

const weather: Extra = {
  id: "acme.weather",
  url: "https://example.com/weather.git",
  rev: OLD_REV,
  hash: HASH,
  kinds: ["bar-widget"],
  entryPoints: { barWidget: "Widget.qml" },
  name: "Weather",
  version: "1",
};
const notes: Extra = {
  id: "acme.notes",
  url: "https://example.com/notes.git",
  rev: OLD_REV,
  hash: HASH,
  kinds: ["launcher"],
  entryPoints: { launcher: "Notes.qml" },
  name: "Notes",
  version: "1",
  prefix: "?",
};

function writeUserState(extraPlugins: Extra[]): void {
  const cfg = join(dir, "config", "marchyo");
  mkdirSync(cfg, { recursive: true });
  writeFileSync(join(cfg, "state.json"), JSON.stringify({ shell: { extraPlugins } }));
}

const lock: PluginLock = {
  lockVersion: 1,
  plugins: [
    {
      id: "acme.clock",
      name: "Clock",
      version: "3",
      kinds: ["bar-widget"],
      entryPoints: { barWidget: "Clock.qml" },
      prefix: null,
      storePath: "/nix/store/x-clock",
      source: null,
    },
    {
      id: "acme.weather",
      name: "Weather",
      version: "1",
      kinds: ["bar-widget"],
      entryPoints: { barWidget: "Widget.qml" },
      prefix: null,
      storePath: "/nix/store/x-weather",
      source: { url: weather.url, rev: OLD_REV },
    },
  ],
};

async function captureStdout(fn: () => Promise<number>): Promise<{ code: number; out: string }> {
  let out = "";
  const spy = spyOn(process.stdout, "write").mockImplementation((chunk: unknown) => {
    out += String(chunk);
    return true;
  });
  try {
    return { code: await fn(), out };
  } finally {
    spy.mockRestore();
  }
}

test("pendingPlugins finds declared plugins absent from the lock or at another rev", () => {
  expect(pendingPlugins([weather, notes], lock).map((p) => p.id)).toEqual(["acme.notes"]);
  const bumped = { ...weather, rev: NEW_REV };
  expect(pendingPlugins([bumped], lock).map((p) => p.id)).toEqual(["acme.weather"]);
});

test("list shows baked plugins as flake/cli and the rest as pending rebuild", async () => {
  writeUserState([weather, notes]);
  const { code, out } = await captureStdout(() => runPluginList(rt, { lock }));
  expect(code).toBe(0);
  const lines = out.trim().split("\n");
  expect(lines).toEqual([
    "acme.clock\tbar-widget\t3\tflake",
    "acme.weather\tbar-widget\t1\tcli",
    "acme.notes\tlauncher\t1\tpending rebuild",
  ]);
});

test("list --json returns the lock and the pending entries", async () => {
  writeUserState([weather, notes]);
  const { out } = await captureStdout(() => runPluginList({ ...rt, format: "json" }, { lock }));
  const j = JSON.parse(out) as { lock: PluginLock; pending: Extra[] };
  expect(j.lock.plugins.length).toBe(2);
  expect(j.pending.map((p) => p.id)).toEqual(["acme.notes"]);
});

function manifestTreeFor(m: Record<string, unknown>): string {
  const tree = mkdtempSync(join(dir, "tree-"));
  writeFileSync(join(tree, "manifest.json"), JSON.stringify({ schemaVersion: 1, ...m }));
  return tree;
}

const weatherManifest = {
  id: "acme.weather",
  name: "Weather",
  version: "1",
  kinds: ["bar-widget"],
  entryPoints: { barWidget: "Widget.qml" },
};

test("update with an unchanged rev and manifest is up to date and does not rebuild", async () => {
  writeUserState([weather]);
  const tree = manifestTreeFor(weatherManifest);
  let calls = 0;
  const code = await runPluginUpdate(rt, undefined, {
    prefetch: async () => ({ rev: OLD_REV, hash: HASH, path: tree }),
    persist: async () => {
      calls++;
      return 0;
    },
  });
  expect(code).toBe(0);
  expect(calls).toBe(0);
});

test("update rewrites rev, hash and manifest fields in one persist call", async () => {
  writeUserState([weather, notes]);
  const weatherTree = manifestTreeFor({ ...weatherManifest, version: "2" });
  const notesTree = manifestTreeFor({
    id: "acme.notes",
    name: "Notes",
    version: "1",
    kinds: ["launcher"],
    entryPoints: { launcher: "Notes.qml" },
    prefix: "?",
  });
  const patches: State[] = [];
  const code = await runPluginUpdate(rt, undefined, {
    prefetch: async (url) =>
      url === weather.url
        ? { rev: NEW_REV, hash: "sha256-new", path: weatherTree }
        : { rev: OLD_REV, hash: HASH, path: notesTree },
    persist: async (_rt, patch) => {
      patches.push(patch);
      return 0;
    },
  });
  expect(code).toBe(0);
  expect(patches.length).toBe(1);
  const next = patches[0]?.shell?.extraPlugins ?? [];
  expect(next.map((p) => p.id)).toEqual(["acme.weather", "acme.notes"]);
  expect(next[0]).toMatchObject({ rev: NEW_REV, hash: "sha256-new", version: "2" });
  expect(next[1]).toEqual(notes);
});

test("update --rev pins the one named plugin", async () => {
  writeUserState([weather]);
  const tree = manifestTreeFor(weatherManifest);
  const asked: (string | undefined)[] = [];
  const code = await runPluginUpdate(rt, "acme.weather", {
    rev: NEW_REV,
    prefetch: async (_url, rev) => {
      asked.push(rev);
      return { rev: NEW_REV, hash: HASH, path: tree };
    },
    persist: async () => 0,
  });
  expect(code).toBe(0);
  expect(asked).toEqual([NEW_REV]);
});

test("update rejects a manifest that turned invalid", async () => {
  writeUserState([weather]);
  const tree = manifestTreeFor({ ...weatherManifest, kinds: ["panel"] });
  let calls = 0;
  const code = await runPluginUpdate(rt, undefined, {
    prefetch: async () => ({ rev: NEW_REV, hash: HASH, path: tree }),
    persist: async () => {
      calls++;
      return 0;
    },
  });
  expect(code).toBe(1);
  expect(calls).toBe(0);
});

test("update of an unknown id exits 1, and --rev without an id is a usage error", async () => {
  writeUserState([weather]);
  expect(await runPluginUpdate(rt, "nobody.here", { prefetch: async () => null })).toBe(1);
  expect(await runPluginUpdate(rt, undefined, { rev: NEW_REV })).toBe(2);
});

test("doctor plugin check warns on declared plugins missing from the lock", () => {
  expect(checkPluginLock(null, [weather]).status).toBe("skip");
  expect(checkPluginLock(lock, []).status).toBe("skip");
  expect(checkPluginLock(lock, [weather]).status).toBe("pass");
  const c = checkPluginLock(lock, [weather, notes]);
  expect(c.status).toBe("warn");
  expect(c.detail).toBe("declared but not built yet: acme.notes; rebuild");
});
