import { afterAll, beforeAll, expect, spyOn, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type PluginLock, type Runtime, type State, PLUGIN_KINDS } from "@marchyo/core";
import { checkDevPlugins, checkPluginLock } from "../src/commands/doctor.ts";
import {
  type PluginPrefetch,
  pendingPlugins,
  runPluginAdd,
  runPluginDev,
  runPluginList,
  runPluginRemove,
  runPluginUpdate,
  runPluginValidate,
  validateManifest,
  validatePluginDir,
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
  writeFileSync(join(manifestTree, "Panel.qml"), "import QtQuick\nItem {}\n");
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

test("kind map is the closed set of marchyo and omarchy kinds", () => {
  expect(PLUGIN_KINDS).toEqual({
    "bar-widget": "barWidget",
    launcher: "launcher",
    daemon: "daemon",
    bar: "bar",
    panel: "panel",
    menu: "menu",
    overlay: "overlay",
    service: "service",
  });
});

test("manifest with an unknown kind is rejected", () => {
  const r = validateManifest({ ...base, kinds: ["widget"], entryPoints: { widget: "P.qml" } });
  expect(r).toContain("unknown plugin kind 'widget'");
});

test("a panel manifest keeps keepLoaded and rejects a non-boolean one", () => {
  const ok = validateManifest({ ...base, kinds: ["panel"], entryPoints: { panel: "P.qml" }, keepLoaded: true });
  expect(ok).toMatchObject({ keepLoaded: true });
  const bad = validateManifest({ ...base, kinds: ["panel"], entryPoints: { panel: "P.qml" }, keepLoaded: "yes" });
  expect(bad).toBe("manifest keepLoaded must be a boolean");
});

test("replaces is carried through and must be a list of distinct role names", () => {
  const p = { ...base, kinds: ["panel"], entryPoints: { panel: "P.qml" } };
  expect(validateManifest({ ...p, replaces: ["panel.weather"] })).toMatchObject({ replaces: ["panel.weather"] });
  expect(validateManifest({ ...p, replaces: "panel.weather" })).toBe(
    "manifest replaces must be an array of native role names",
  );
  expect(validateManifest({ ...p, replaces: ["polkit", "polkit"] })).toBe("manifest replaces has duplicates");
});

test("the barWidget block is checked and needs the bar-widget kind", () => {
  const w = { kinds: ["bar-widget"], entryPoints: { barWidget: "W.qml" } };
  expect(validateManifest({ ...base, ...w, barWidget: { defaultSection: "left", allowMultiple: true } })).toMatchObject({
    barWidget: { defaultSection: "left" },
  });
  expect(validateManifest({ ...base, ...w, barWidget: { defaultSection: "middle" } })).toContain("defaultSection");
  expect(validateManifest({ ...base, ...w, barWidget: { nope: 1 } })).toContain("barWidget.nope");
  expect(
    validateManifest({ ...base, kinds: ["panel"], entryPoints: { panel: "P.qml" }, barWidget: {} }),
  ).toBe("manifest barWidget only applies to the 'bar-widget' kind");
});

test("marchyo.* and omarchy.* ids are reserved unless the omarchy one is lifted", () => {
  const m = { kinds: ["panel"], entryPoints: { panel: "P.qml" } };
  expect(validateManifest({ ...base, ...m, id: "marchyo.x" })).toContain("reserved marchyo.*");
  expect(validateManifest({ ...base, ...m, id: "omarchy.x" })).toContain("reserved omarchy.*");
  expect(validateManifest({ ...base, ...m, id: "omarchy.x" }, { omarchyFirstParty: true })).toMatchObject({
    id: "omarchy.x",
  });
  expect(validateManifest({ ...base, ...m, id: "marchyo.x" }, { omarchyFirstParty: true })).toContain(
    "reserved marchyo.*",
  );
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
  for (const ep of Object.values((m.entryPoints ?? {}) as Record<string, string>))
    writeFileSync(join(tree, ep), "Item {}");
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

// ── plugin directories: validate and the dev loader ─────────────────────────

function makePlugin(root: string, files: Record<string, string>): string {
  for (const [rel, text] of Object.entries(files)) {
    const abs = join(root, rel);
    mkdirSync(join(abs, ".."), { recursive: true });
    writeFileSync(abs, text);
  }
  return root;
}

const panelManifest = (over: Record<string, unknown> = {}): string =>
  JSON.stringify({
    schemaVersion: 1,
    id: "acme.panel",
    kinds: ["panel"],
    entryPoints: { panel: "Panel.qml" },
    ...over,
  });

test("validatePluginDir accepts a plugin with a sibling manifest", () => {
  const d = makePlugin(join(dir, "ok-sibling"), {
    "manifest.json": panelManifest(),
    "Panel.qml": "Item {}",
    "widgets/Spacer.manifest.json": JSON.stringify({
      schemaVersion: 1,
      id: "acme.spacer",
      kinds: ["bar-widget"],
      entryPoints: { barWidget: "Spacer.qml" },
      barWidget: { allowMultiple: true },
    }),
    "widgets/Spacer.qml": "Item {}",
  });
  const r = validatePluginDir(d);
  expect(r.problems).toEqual([]);
  expect(r.siblings.map((s) => s.id)).toEqual(["acme.spacer"]);
  expect(r.siblings[0]?.manifest).toBe("widgets/Spacer.manifest.json");
});

test("validatePluginDir reports every problem", () => {
  const d = makePlugin(join(dir, "bad-plugin"), {
    "manifest.json": panelManifest({ entryPoints: { panel: "../Panel.qml" } }),
    "extra.manifest.json": panelManifest({ entryPoints: { panel: "Gone.qml" } }),
  });
  symlinkSync("/etc/passwd", join(d, "link.qml"));
  const r = validatePluginDir(d);
  expect(r.problems.length).toBeGreaterThanOrEqual(4);
  expect(r.problems.join("\n")).toContain("symlink not allowed: link.qml");
  expect(r.problems.join("\n")).toContain("unsafe entry point path '../Panel.qml'");
  expect(r.problems.join("\n")).toContain("duplicate plugin id 'acme.panel'");
  expect(r.problems.join("\n")).toContain("entry point 'Gone.qml' does not exist");
});

test("plugin validate exits 1 on a bad tree and 0 on a good one", async () => {
  expect(await runPluginValidate(rt, join(dir, "bad-plugin"))).toBe(1);
  expect(await runPluginValidate(rt, join(dir, "ok-sibling"))).toBe(0);
  expect(await runPluginValidate(rt, join(dir, "missing"))).toBe(1);
});

function devFixture(): { devDir: string; shellDir: string } {
  const shellDir = join(dir, "shell-share");
  mkdirSync(join(shellDir, "compat"), { recursive: true });
  writeFileSync(
    join(shellDir, "compat", "rewrite.sed"),
    "s/(^|[^.A-Za-z0-9_])import qs\\.Ui\\b/\\1import qs.compat.Ui/g\n",
  );
  return { devDir: join(dir, "state", "dev-plugins"), shellDir };
}

test("plugin dev refuses while the shell has the loader off", async () => {
  const { devDir, shellDir } = devFixture();
  const d = makePlugin(join(dir, "dev-off"), { "manifest.json": panelManifest(), "Panel.qml": "Item {}" });
  const code = await runPluginDev(rt, d, { devEnabled: false, devDir, shellDir });
  expect(code).toBe(1);
  expect(existsSync(devDir)).toBe(false);
});

test("plugin dev syncs a rewritten copy, writes the index and asks for a rescan", async () => {
  const { devDir, shellDir } = devFixture();
  const d = makePlugin(join(dir, "dev-on"), {
    "manifest.json": panelManifest(),
    "Panel.qml": "import qs.Ui\nItem {}\n",
    ".git/config": "x",
  });
  let rescans = 0;
  const code = await runPluginDev(rt, d, {
    devEnabled: true,
    devDir,
    shellDir,
    rescan: async () => {
      rescans++;
      return "ok";
    },
  });
  expect(code).toBe(0);
  expect(rescans).toBe(1);
  expect(readFileSync(join(devDir, "acme.panel", "Panel.qml"), "utf8")).toContain("import qs.compat.Ui");
  expect(readFileSync(join(d, "Panel.qml"), "utf8")).toContain("import qs.Ui");
  expect(existsSync(join(devDir, "acme.panel", ".git"))).toBe(false);
  const index = JSON.parse(readFileSync(join(devDir, "index.json"), "utf8")) as {
    plugins: { id: string; entryPoints: Record<string, string> }[];
  };
  expect(index.plugins).toEqual([expect.objectContaining({ id: "acme.panel", entryPoints: { panel: "Panel.qml" } })]);
  expect((await Bun.file(join(devDir, "index.json")).stat()).mode & 0o777).toBe(0o600);
});

test("add keeps the manifest replaces in the state entry and its siblings", async () => {
  const tree = makePlugin(join(dir, "add-replaces"), {
    "manifest.json": panelManifest({ id: "acme.forecast", replaces: ["panel.weather"] }),
    "Panel.qml": "Item {}",
    "w/Widget.manifest.json": JSON.stringify({
      schemaVersion: 1,
      id: "acme.forecast-widget",
      kinds: ["panel"],
      entryPoints: { panel: "Widget.qml" },
      replaces: ["panel.network"],
    }),
    "w/Widget.qml": "Item {}",
  });
  const { code, out } = await captureStdout(() =>
    runPluginAdd(rt, "https://example.com/w.git", { dryRun: true, prefetch: stubPrefetch(tree) }),
  );
  expect(code).toBe(0);
  const entry = (JSON.parse(out.trim().split("\n").pop() ?? "{}") as State).shell?.extraPlugins?.find((p) => p.id === "acme.forecast");
  expect(entry?.replaces).toEqual(["panel.weather"]);
  expect(entry?.siblings?.[0]).toMatchObject({ id: "acme.forecast-widget", replaces: ["panel.network"] });
});

test("plugin dev keeps the manifest replaces in the index", async () => {
  const { devDir, shellDir } = devFixture();
  const d = makePlugin(join(dir, "dev-replaces"), {
    "manifest.json": panelManifest({ id: "acme.repl", replaces: ["panel.weather"] }),
    "Panel.qml": "Item {}",
  });
  expect(await runPluginDev(rt, d, { devEnabled: true, devDir, shellDir, rescan: async () => "ok" })).toBe(0);
  const index = JSON.parse(readFileSync(join(devDir, "index.json"), "utf8")) as {
    plugins: { id: string; replaces?: string[] }[];
  };
  expect(index.plugins.find((p) => p.id === "acme.repl")?.replaces).toEqual(["panel.weather"]);
});

test("plugin dev refuses kinds that need a rebuild and removes by id", async () => {
  const { devDir, shellDir } = devFixture();
  const svc = makePlugin(join(dir, "dev-svc"), {
    "manifest.json": panelManifest({ id: "acme.svc", kinds: ["service"], entryPoints: { service: "S.qml" } }),
    "S.qml": "Item {}",
  });
  expect(await runPluginDev(rt, svc, { devEnabled: true, devDir, shellDir, rescan: async () => "ok" })).toBe(1);

  const ok = makePlugin(join(dir, "dev-rm"), { "manifest.json": panelManifest({ id: "acme.rm" }), "Panel.qml": "Item {}" });
  await runPluginDev(rt, ok, { devEnabled: true, devDir, shellDir, rescan: async () => "ok" });
  expect(await runPluginDev(rt, "acme.rm", { devEnabled: true, devDir, shellDir, remove: true, rescan: async () => "ok" })).toBe(0);
  expect(existsSync(join(devDir, "acme.rm"))).toBe(false);
  expect(await runPluginDev(rt, "acme.rm", { devEnabled: true, devDir, shellDir, remove: true, rescan: async () => "ok" })).toBe(1);
});

test("plugin ids with traversal or shell characters are rejected", async () => {
  const m = { schemaVersion: 1, kinds: ["panel"], entryPoints: { panel: "Panel.qml" } };
  for (const id of ["../../x", "a/b", "a..b", ".hidden", "x$(id)", "a b"])
    expect(validateManifest({ ...m, id })).toContain("must match");
  expect(typeof validateManifest({ ...m, id: "acme.ok-1_x" })).toBe("object");

  const { devDir, shellDir } = devFixture();
  const victim = join(dir, "victim");
  mkdirSync(victim, { recursive: true });
  writeFileSync(join(victim, "keep"), "x");
  const evil = makePlugin(join(dir, "dev-evil"), {
    "manifest.json": panelManifest({ id: `../../${"victim"}` }),
    "Panel.qml": "Item {}",
  });
  const opts = { devEnabled: true, devDir, shellDir, rescan: async () => "ok" };
  expect(await runPluginDev(rt, evil, opts)).toBe(1);
  expect(existsSync(join(victim, "keep"))).toBe(true);
  expect(existsSync(join(victim, "Panel.qml"))).toBe(false);

  mkdirSync(devDir, { recursive: true });
  expect(await runPluginDev(rt, "../../victim", { ...opts, remove: true })).toBe(1);
  expect(existsSync(join(victim, "keep"))).toBe(true);
});

test("plugin dev --watch syncs again on each change until the waiter stops", async () => {
  const { devDir, shellDir } = devFixture();
  const d = makePlugin(join(dir, "dev-watch"), { "manifest.json": panelManifest({ id: "acme.w" }), "Panel.qml": "Item {}" });
  let rescans = 0;
  let waits = 0;
  const code = await runPluginDev(rt, d, {
    devEnabled: true,
    devDir,
    shellDir,
    watch: true,
    rescan: async () => {
      rescans++;
      return "ok";
    },
    waitForChange: async () => ++waits <= 2,
  });
  expect(code).toBe(0);
  expect(rescans).toBe(3);
});

test("doctor warns while the dev loader mounts plugins", () => {
  expect(checkDevPlugins(false, ["a.b"]).status).toBe("skip");
  expect(checkDevPlugins(true, []).status).toBe("pass");
  expect(checkDevPlugins(true, ["a.b"]).status).toBe("warn");
});
