import {
  chmodSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  watch,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import {
  type PluginKind,
  type PluginLock,
  type Runtime,
  type State,
  PLUGIN_KINDS,
  DEV_PLUGIN_KINDS,
  captureArgv,
  commandAvailable,
  data,
  devPluginsDir,
  err,
  hint,
  info,
  isPluginKind,
  ok,
  readPluginLock,
  readState,
  reservedIdNamespace,
  reservedPrefixClash,
  shellDevPluginsEnabled,
  shellIpc,
  shellShareDir,
  tr,
  warn,
} from "@marchyo/core";
import { type DeclarativeOpts, persistAndRebuild } from "./declarative.ts";

// `marchyo plugin`: the CLI leg of the build-time shell plugin platform. A
// plugin is Nix-declared and baked into the store shell; there is no runtime
// discovery. `add` pins a git source (rev + hash) and mirrors its manifest
// fields into the marchyoCliState sidecar (marchyo.shell.extraPlugins); a
// rebuild builds it via pkgs.mkMarchyoShellPlugin and bakes it in. `update`
// re-pins those sources. `list` reads the installed shell's plugins.lock.json,
// which records every plugin that build baked. Hand-written
// marchyo.shell.plugins in the flake always wins (the sidecar merges at
// mkDefault).

type ExtraPlugin = NonNullable<
  NonNullable<State["shell"]>["extraPlugins"]
>[number];

// Resolved pin plus the fetched tree path, so the manifest can be read without
// a second network round-trip. null on any prefetch failure (offline, bad URL,
// unreachable rev).
export type PluginPin = { rev: string; hash: string; path: string };
export type PluginPrefetch = (
  url: string,
  rev?: string,
) => Promise<PluginPin | null>;

// Default pin: nix-prefetch-git clones, resolves the rev, and prints JSON with
// the store path and the fetchgit hash. Newer versions emit `hash` (SRI);
// older ones only `sha256`, so accept either.
const defaultPrefetch: PluginPrefetch = async (url, rev) => {
  const argv = [
    "nix-prefetch-git",
    "--quiet",
    "--url",
    url,
    ...(rev !== undefined ? ["--rev", rev] : []),
  ];
  const r = await captureArgv(argv);
  if (r.code !== 0) return null;
  try {
    const j = JSON.parse(r.stdout) as {
      rev?: string;
      hash?: string;
      sha256?: string;
      path?: string;
    };
    const hash = j.hash ?? j.sha256;
    if (!j.rev || !hash || !j.path) return null;
    return { rev: j.rev, hash, path: j.path };
  } catch {
    return null;
  }
};

export type Manifest = {
  id: string;
  kinds: PluginKind[];
  entryPoints: Record<string, string>;
  name?: string;
  version?: string;
  prefix?: string;
  keepLoaded?: boolean;
  replaces?: string[];
  barWidget?: Record<string, unknown>;
};

// A sibling `*.manifest.json`: its own plugin id, entry points relative to
// the manifest's directory, `manifest` the path from the plugin root.
export type SiblingManifest = Manifest & { manifest: string };

const KIND_LIST = Object.keys(PLUGIN_KINDS).join(", ");

const BAR_SECTIONS = ["left", "centerBegin", "center", "centerEnd", "tray", "right"];
const BAR_WIDGET_KEYS = [
  "displayName",
  "description",
  "category",
  "allowMultiple",
  "defaultSection",
  "defaults",
  "schema",
  "settingsForm",
];

function barWidgetProblem(b: unknown): string | null {
  if (typeof b !== "object" || b === null || Array.isArray(b))
    return "manifest barWidget must be an object";
  const w = b as Record<string, unknown>;
  const unknownKey = Object.keys(w).find((k) => !BAR_WIDGET_KEYS.includes(k));
  if (unknownKey !== undefined) return `barWidget.${unknownKey} is not a known key`;
  if (w.allowMultiple !== undefined && typeof w.allowMultiple !== "boolean")
    return "barWidget.allowMultiple must be a boolean";
  if (
    w.defaultSection !== undefined &&
    !BAR_SECTIONS.includes(w.defaultSection as string)
  )
    return `barWidget.defaultSection must be one of: ${BAR_SECTIONS.join(", ")}`;
  if (
    w.defaults !== undefined &&
    (typeof w.defaults !== "object" || w.defaults === null || Array.isArray(w.defaults))
  )
    return "barWidget.defaults must be an object";
  if (w.schema !== undefined && !Array.isArray(w.schema))
    return "barWidget.schema must be an array";
  return null;
}

// Same shape the shell (PluginManifest.js devEntry) and plugin.nix accept.
export function isValidPluginId(id: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) && !id.includes("..");
}

export type ValidateOpts = {
  // Lift the omarchy.* namespace reservation (the vendored omarchy plugins).
  omarchyFirstParty?: boolean;
};

// Validate a parsed manifest.json. Returns the manifest, or a message naming
// the first problem. The kind, entry point and prefix rules match
// packages/marchyo-shell/plugin.nix, so a manifest accepted here builds.
export function validateManifest(
  raw: unknown,
  opts: ValidateOpts = {},
): Manifest | string {
  if (typeof raw !== "object" || raw === null) return "manifest.json is not an object";
  const m = raw as Record<string, unknown>;
  if (m.schemaVersion !== 1) return "manifest schemaVersion must be 1";
  if (typeof m.id !== "string" || m.id === "") return "manifest id is missing";
  if (!isValidPluginId(m.id))
    return `plugin id '${m.id}' must match [A-Za-z0-9][A-Za-z0-9._-]* and not contain '..'`;
  const ns = reservedIdNamespace(m.id);
  if (ns !== null && !(ns === "omarchy." && opts.omarchyFirstParty === true))
    return `plugin id '${m.id}' uses the reserved ${ns}* namespace`;
  if (
    !Array.isArray(m.kinds) ||
    m.kinds.length === 0 ||
    !m.kinds.every((k) => typeof k === "string")
  )
    return "manifest kinds must be a non-empty string array";
  const kinds = m.kinds as string[];
  const unknown = kinds.find((k) => !isPluginKind(k));
  if (unknown !== undefined)
    return `unknown plugin kind '${unknown}' (expected one of: ${KIND_LIST})`;
  if (new Set(kinds).size !== kinds.length) return "manifest kinds has duplicates";
  if (
    typeof m.entryPoints !== "object" ||
    m.entryPoints === null ||
    Array.isArray(m.entryPoints) ||
    !Object.values(m.entryPoints).every((v) => typeof v === "string" && v !== "")
  )
    return "manifest entryPoints must map each kind's key to a QML file";
  const entryPoints = m.entryPoints as Record<string, string>;
  const wanted = (kinds as PluginKind[]).map((k) => PLUGIN_KINDS[k]);
  for (const k of kinds as PluginKind[]) {
    if (!Object.hasOwn(entryPoints, PLUGIN_KINDS[k]))
      return `kind '${k}' needs entryPoints.${PLUGIN_KINDS[k]}`;
  }
  const extra = Object.keys(entryPoints).find(
    (key) => !(wanted as string[]).includes(key),
  );
  if (extra !== undefined)
    return `entryPoints.${extra} matches no declared kind (kinds: ${kinds.join(", ")})`;
  if (m.prefix !== undefined && typeof m.prefix !== "string")
    return "manifest prefix must be a string";
  const prefix = m.prefix as string | undefined;
  if (kinds.includes("launcher")) {
    if (prefix === undefined || prefix === "") return "kind 'launcher' needs a non-empty prefix";
    if (/\s/.test(prefix)) return `launcher prefix '${prefix}' contains whitespace`;
    const clash = reservedPrefixClash(prefix);
    if (clash !== null)
      return `launcher prefix '${prefix}' starts with '${clash}', reserved for the built-in launcher prefixes`;
  } else if (prefix !== undefined) {
    return "manifest prefix only applies to the 'launcher' kind";
  }
  if (m.keepLoaded !== undefined && typeof m.keepLoaded !== "boolean")
    return "manifest keepLoaded must be a boolean";
  if (
    m.replaces !== undefined &&
    (!Array.isArray(m.replaces) || !m.replaces.every((r) => typeof r === "string" && r !== ""))
  )
    return "manifest replaces must be an array of native role names";
  const replaces = m.replaces as string[] | undefined;
  if (replaces !== undefined && new Set(replaces).size !== replaces.length)
    return "manifest replaces has duplicates";
  if (m.barWidget !== undefined) {
    if (!kinds.includes("bar-widget"))
      return "manifest barWidget only applies to the 'bar-widget' kind";
    const problem = barWidgetProblem(m.barWidget);
    if (problem !== null) return problem;
  }
  return {
    id: m.id,
    kinds: kinds as PluginKind[],
    entryPoints,
    ...(typeof m.name === "string" ? { name: m.name } : {}),
    ...(typeof m.version === "string" ? { version: m.version } : {}),
    ...(prefix !== undefined ? { prefix } : {}),
    ...(typeof m.keepLoaded === "boolean" ? { keepLoaded: m.keepLoaded } : {}),
    ...(replaces !== undefined ? { replaces } : {}),
    ...(m.barWidget !== undefined
      ? { barWidget: m.barWidget as Record<string, unknown> }
      : {}),
  };
}

const SKIP_DIRS = new Set([".git", "node_modules", ".direnv"]);

// Every file under `root` (relative paths), refusing symlinks. Returns the
// paths and the symlinks found.
function walk(root: string): { files: string[]; links: string[] } {
  const files: string[] = [];
  const links: string[] = [];
  const visit = (dir: string): void => {
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      const abs = join(dir, e.name);
      if (e.isSymbolicLink()) links.push(relative(root, abs));
      else if (e.isDirectory()) {
        if (!SKIP_DIRS.has(e.name)) visit(abs);
      } else files.push(relative(root, abs));
    }
  };
  visit(root);
  return { files, links };
}

function safeRel(p: string): boolean {
  return p !== "" && !p.startsWith("/") && !p.includes("..") && !p.includes("\0");
}

export type PluginDirReport = {
  manifest: Manifest | null;
  siblings: SiblingManifest[];
  problems: string[];
};

// The plugins.nix build checks, run on a checkout: manifest.json and every
// sibling *.manifest.json validate, their entry points exist, ids are unique
// and no symlink is inside. Every problem is reported, not just the first.
export function validatePluginDir(dir: string, opts: ValidateOpts = {}): PluginDirReport {
  const problems: string[] = [];
  const report: PluginDirReport = { manifest: null, siblings: [], problems };
  if (!existsSync(join(dir, "manifest.json"))) {
    problems.push("manifest.json missing at the plugin root");
    return report;
  }
  const { files, links } = walk(dir);
  for (const l of links) problems.push(`symlink not allowed: ${l}`);

  const checkFile = (rel: string, eps: Record<string, string>, base: string): void => {
    for (const ep of Object.values(eps)) {
      const path = base === "" ? ep : join(base, ep);
      if (!safeRel(ep)) problems.push(`${rel}: unsafe entry point path '${ep}'`);
      else if (!files.includes(path)) problems.push(`${rel}: entry point '${ep}' does not exist`);
    }
  };

  const load = (rel: string): Manifest | null => {
    let raw: unknown;
    try {
      raw = JSON.parse(readFileSync(join(dir, rel), "utf8"));
    } catch {
      problems.push(`${rel}: not valid JSON`);
      return null;
    }
    const v = validateManifest(raw, opts);
    if (typeof v === "string") {
      problems.push(`${rel}: ${v}`);
      return null;
    }
    return v;
  };

  report.manifest = load("manifest.json");
  if (report.manifest !== null) checkFile("manifest.json", report.manifest.entryPoints, "");

  const seen = new Set(report.manifest !== null ? [report.manifest.id] : []);
  for (const rel of files.filter((f) => f.endsWith(".manifest.json")).sort()) {
    const m = load(rel);
    if (m === null) continue;
    if (seen.has(m.id)) problems.push(`${rel}: duplicate plugin id '${m.id}'`);
    seen.add(m.id);
    checkFile(rel, m.entryPoints, dirname(rel) === "." ? "" : dirname(rel));
    report.siblings.push({ ...m, manifest: rel });
  }
  return report;
}

type PluginTree = { manifest: Manifest; siblings: SiblingManifest[] };

// Validate a fetched tree the way the build does (manifest.json, sibling
// manifests, entry points, symlinks); a message naming the first problem when
// it does not.
function readManifest(treePath: string): PluginTree | string {
  const report = validatePluginDir(treePath);
  if (report.problems.length > 0 || report.manifest === null)
    return report.problems[0] ?? "manifest.json missing at the repo root";
  return { manifest: report.manifest, siblings: report.siblings };
}

function manifestFields(m: Manifest): Record<string, unknown> {
  return {
    ...(m.name !== undefined ? { name: m.name } : {}),
    ...(m.version !== undefined ? { version: m.version } : {}),
    ...(m.prefix !== undefined ? { prefix: m.prefix } : {}),
    ...(m.keepLoaded !== undefined ? { keepLoaded: m.keepLoaded } : {}),
    ...(m.replaces !== undefined ? { replaces: m.replaces } : {}),
    ...(m.barWidget !== undefined ? { barWidget: m.barWidget } : {}),
  };
}

// The state entry for a pinned source and its manifest.
function toEntry(url: string, pin: PluginPin, tree: PluginTree): ExtraPlugin {
  const { manifest, siblings } = tree;
  return {
    id: manifest.id,
    url,
    rev: pin.rev,
    hash: pin.hash,
    kinds: manifest.kinds,
    entryPoints: manifest.entryPoints,
    ...manifestFields(manifest),
    ...(siblings.length > 0
      ? {
          siblings: siblings.map((s) => ({
            manifest: s.manifest,
            id: s.id,
            kinds: s.kinds,
            entryPoints: s.entryPoints,
            ...manifestFields(s),
          })),
        }
      : {}),
  } as ExtraPlugin;
}

// Resolve the prefetcher. Null (after reporting) when the default needs
// nix-prefetch-git and it is not on PATH.
function prefetcher(rt: Runtime, injected: PluginPrefetch | undefined, verb: string): PluginPrefetch | null {
  if (injected !== undefined) return injected;
  if (!commandAvailable("nix-prefetch-git")) {
    err(rt, tr("plugin.nixPrefetchGitNotFound"));
    hint(rt, `Try: nix shell nixpkgs#nix-prefetch-git -c marchyo plugin ${verb} …`);
    return null;
  }
  return defaultPrefetch;
}

export type PluginAddOpts = DeclarativeOpts & {
  rev?: string;
  prefetch?: PluginPrefetch;
};

export async function runPluginAdd(
  rt: Runtime,
  url: string,
  opts: PluginAddOpts,
): Promise<number> {
  const prefetch = prefetcher(rt, opts.prefetch, "add");
  if (prefetch === null) return 1;

  info(rt, tr("plugin.fetching", url));
  const pin = await prefetch(url, opts.rev);
  if (pin === null) {
    err(rt, tr("plugin.couldNotFetch", url));
    hint(rt, tr("plugin.checkTheUrlAndRevision"));
    return 1;
  }

  const tree = readManifest(pin.path);
  if (typeof tree === "string") {
    err(rt, tr("plugin.invalidPlugin", tree));
    return 1;
  }
  const manifest = tree.manifest;

  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.shell?.extraPlugins ?? [];
  if (existing.some((p) => p.id === manifest.id)) {
    err(rt, tr("plugin.pluginIsAlreadyAdded", manifest.id));
    hint(rt, `Try: marchyo plugin remove ${manifest.id} first`);
    return 1;
  }

  const entry = toEntry(url, pin, tree);
  return persistAndRebuild(
    rt,
    { shell: { extraPlugins: [...existing, entry] } },
    opts,
    `plugin '${manifest.id}' added (${url}@${pin.rev.slice(0, 12)})`,
  );
}

export async function runPluginRemove(
  rt: Runtime,
  id: string,
  opts: DeclarativeOpts,
): Promise<number> {
  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.shell?.extraPlugins ?? [];
  if (!existing.some((p) => p.id === id)) {
    err(rt, tr("plugin.pluginIsNotCliManaged", id));
    hint(
      rt,
      tr("plugin.flakeDeclaredPluginsLiveIn"),
    );
    return 1;
  }
  return persistAndRebuild(
    rt,
    { shell: { extraPlugins: existing.filter((p) => p.id !== id) } },
    opts,
    `plugin '${id}' removed`,
  );
}

export type PluginUpdateOpts = DeclarativeOpts & {
  rev?: string;
  prefetch?: PluginPrefetch;
  persist?: typeof persistAndRebuild;
};

// Re-pin CLI-added plugins at their URL (HEAD, or --rev for a single id) and
// refresh the manifest fields. One rebuild covers every changed plugin; no
// rebuild when nothing changed.
export async function runPluginUpdate(
  rt: Runtime,
  id: string | undefined,
  opts: PluginUpdateOpts,
): Promise<number> {
  if (opts.rev !== undefined && id === undefined) {
    err(rt, tr("plugin.revNeedsPluginId"));
    hint(rt, "Try: marchyo plugin update <id> --rev <rev>");
    return 2;
  }
  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.shell?.extraPlugins ?? [];
  if (id !== undefined && !existing.some((p) => p.id === id)) {
    err(rt, tr("plugin.pluginIsNotCliManaged", id));
    hint(
      rt,
      tr("plugin.seeMarchyoPluginListFlake"),
    );
    return 1;
  }
  const targets = existing.filter((p) => id === undefined || p.id === id);
  if (targets.length === 0) {
    ok(rt, tr("plugin.noCliAddedPluginsTo"));
    return 0;
  }
  const prefetch = prefetcher(rt, opts.prefetch, "update");
  if (prefetch === null) return 1;

  const updated = new Map<string, ExtraPlugin>();
  const changes: string[] = [];
  for (const p of targets) {
    info(rt, tr("plugin.fetching", p.url));
    const pin = await prefetch(p.url, opts.rev);
    if (pin === null) {
      err(rt, tr("plugin.couldNotFetch", p.url));
      hint(rt, tr("plugin.checkTheUrlAndRevision"));
      return 1;
    }
    const tree = readManifest(pin.path);
    if (typeof tree === "string") {
      err(rt, tr("plugin.invalidPluginAt", p.id, pin.rev.slice(0, 12), tree));
      return 1;
    }
    if (tree.manifest.id !== p.id) {
      err(rt, tr("plugin.pluginNowDeclaresId", p.id, tree.manifest.id));
      hint(rt, `Try: marchyo plugin remove ${p.id}, then marchyo plugin add ${p.url}`);
      return 1;
    }
    const next = toEntry(p.url, pin, tree);
    if (!Bun.deepEquals(next, p)) {
      updated.set(p.id, next);
      changes.push(
        p.rev === next.rev
          ? `${p.id} (manifest refreshed)`
          : `${p.id} ${p.rev.slice(0, 12)} -> ${next.rev.slice(0, 12)}`,
      );
    }
  }

  if (updated.size === 0) {
    ok(rt, id === undefined ? "all plugins up to date" : `plugin '${id}' up to date`);
    return 0;
  }
  const persist = opts.persist ?? persistAndRebuild;
  return persist(
    rt,
    { shell: { extraPlugins: existing.map((p) => updated.get(p.id) ?? p) } },
    opts,
    `plugins updated: ${changes.join(", ")}`,
  );
}

// CLI-declared plugins the lock does not show at their pinned rev: added or
// updated since the last rebuild.
export function pendingPlugins(
  declared: readonly ExtraPlugin[],
  lock: PluginLock,
): ExtraPlugin[] {
  const baked = new Map(lock.plugins.map((p) => [p.id, p]));
  return declared.filter((p) => {
    const b = baked.get(p.id);
    return b === undefined || (b.source !== null && b.source.rev !== p.rev);
  });
}

export type PluginListOpts = {
  // The installed shell's lock; read from the shell on PATH when omitted.
  lock?: PluginLock | null;
};

export async function runPluginList(
  rt: Runtime,
  opts: PluginListOpts = {},
): Promise<number> {
  const state = await readState().catch(() => ({}) as State);
  const plugins = state.shell?.extraPlugins ?? [];
  const lock = opts.lock !== undefined ? opts.lock : readPluginLock();

  if (lock === null) {
    data(rt, { lock: null, plugins }, () => {
      if (plugins.length === 0) return "no CLI-added plugins";
      return plugins
        .map((p) => `${p.id}\t${p.kinds.join(",")}\t${p.url}@${p.rev.slice(0, 12)}`)
        .join("\n");
    });
    hint(
      rt,
      tr("plugin.noPluginsLockJsonIn"),
    );
    return 0;
  }

  const pending = pendingPlugins(plugins, lock);
  data(rt, { lock, pending }, () => {
    const rows = [
      ...lock.plugins.map(
        (p) =>
          `${p.id}\t${p.kinds.join(",")}\t${p.version}\t${p.source === null ? "flake" : "cli"}`,
      ),
      ...pending.map(
        (p) => `${p.id}\t${p.kinds.join(",")}\t${p.version ?? "-"}\tpending rebuild`,
      ),
    ];
    return rows.length === 0 ? "no shell plugins" : rows.join("\n");
  });
  return 0;
}

export type PluginValidateOpts = ValidateOpts;

// `marchyo plugin validate <dir>`: the plugin.nix build checks on a checkout.
export async function runPluginValidate(
  rt: Runtime,
  dir: string,
  opts: PluginValidateOpts = {},
): Promise<number> {
  if (!existsSync(dir)) {
    err(rt, tr("plugin.noSuchDirectory", dir));
    return 1;
  }
  const report = validatePluginDir(dir, opts);
  data(rt, report, () =>
    report.problems.length === 0
      ? `ok: ${report.manifest?.id}${report.siblings.length > 0 ? ` (+${report.siblings.length} sibling)` : ""}`
      : report.problems.map((p) => `invalid: ${p}`).join("\n"),
  );
  return report.problems.length === 0 ? 0 : 1;
}

// ---- marchyo plugin dev ----------------------------------------------------
//
// The opt-in dev loader. It syncs a checkout into
// $XDG_STATE_HOME/marchyo/shell/dev-plugins/<id>/ (a copy, because the compat
// import rewrite runs over the sources and the shell refuses symlinks), writes
// the index.json the shell reads, then asks the shell to reload. The shell
// reads that directory only when marchyo.shell.devPlugins.enable baked it in.

type DevIndexEntry = {
  id: string;
  name: string;
  version: string;
  kinds: string[];
  entryPoints: Record<string, string>;
  prefix?: string;
  keepLoaded?: boolean;
  replaces?: string[];
  barWidget?: Record<string, unknown>;
};

export type PluginDevOpts = {
  watch?: boolean;
  remove?: boolean;
  // Test seams.
  devDir?: string;
  shellDir?: string | null;
  devEnabled?: boolean;
  rescan?: () => Promise<string>;
  waitForChange?: (dir: string) => Promise<boolean>;
};

function readDevIndex(devDir: string): DevIndexEntry[] {
  try {
    const parsed = JSON.parse(readFileSync(join(devDir, "index.json"), "utf8")) as {
      plugins?: DevIndexEntry[];
    };
    return Array.isArray(parsed.plugins) ? parsed.plugins : [];
  } catch {
    return [];
  }
}

function writeDevIndex(devDir: string, plugins: DevIndexEntry[]): void {
  mkdirSync(devDir, { recursive: true, mode: 0o700 });
  chmodSync(devDir, 0o700);
  const tmp = join(devDir, `.index.${process.pid}.tmp`);
  writeFileSync(tmp, JSON.stringify({ plugins }, null, 2), { mode: 0o600 });
  renameSync(tmp, join(devDir, "index.json"));
}

function devEntryOf(m: Manifest, base: string): DevIndexEntry {
  const prefixed = (ep: string): string => (base === "" ? ep : join(base, ep));
  return {
    id: m.id,
    name: m.name ?? m.id,
    version: m.version ?? "0",
    kinds: m.kinds,
    entryPoints: Object.fromEntries(
      Object.entries(m.entryPoints).map(([k, ep]) => [k, prefixed(ep)]),
    ),
    ...(m.prefix !== undefined ? { prefix: m.prefix } : {}),
    ...(m.keepLoaded !== undefined ? { keepLoaded: m.keepLoaded } : {}),
    ...(m.replaces !== undefined ? { replaces: m.replaces } : {}),
    ...(m.barWidget !== undefined ? { barWidget: m.barWidget } : {}),
  };
}

function assertUnder(root: string, target: string): void {
  const r = resolve(root);
  const t = resolve(target);
  if (t === r || !t.startsWith(r + sep)) throw new Error(`refusing path outside ${r}: ${target}`);
}

// Copy `src` over devDir/<id>, without VCS dirs, then apply the compat import
// rewrite to its QML and JS files.
function syncTree(src: string, target: string, devDir: string, rewriteSed: string): void {
  assertUnder(devDir, target);
  rmSync(target, { recursive: true, force: true });
  cpSync(src, target, {
    recursive: true,
    filter: (p) => !SKIP_DIRS.has(p.split("/").pop() ?? "") && !lstatSync(p).isSymbolicLink(),
  });
  const { files } = walk(target);
  const code = files.filter((f) => /\.(qml|js)$/.test(f)).map((f) => join(target, f));
  for (let i = 0; i < code.length; i += 200) {
    const r = Bun.spawnSync(["sed", "-i", "-E", "-f", rewriteSed, ...code.slice(i, i + 200)]);
    if (r.exitCode !== 0) throw new Error(`sed failed: ${r.stderr.toString().trim()}`);
  }
}

const DEV_WARNING =
  "dev plugins are unreviewed, unpinned code that runs unsandboxed with your privileges inside the shell, and any process of yours can replace it. Use this on a development host only.";

async function devOnce(
  rt: Runtime,
  dir: string,
  devDir: string,
  rewriteSed: string,
  rescan: () => Promise<string>,
): Promise<number> {
  const report = validatePluginDir(dir);
  if (report.problems.length > 0 || report.manifest === null) {
    for (const p of report.problems) err(rt, tr("plugin.invalidPlugin", p));
    return 1;
  }
  const all: SiblingManifest[] = [
    { ...report.manifest, manifest: "manifest.json" },
    ...report.siblings,
  ];
  for (const m of all) {
    const bad = m.kinds.find((k) => !DEV_PLUGIN_KINDS.includes(k));
    if (bad !== undefined) {
      err(rt, tr("plugin.devKindNeedsRebuild", m.id, bad));
      hint(rt, tr("plugin.devKindsAllowed", DEV_PLUGIN_KINDS.join(", ")));
      return 1;
    }
  }
  const ids = new Set(all.map((m) => m.id));
  const kept = readDevIndex(devDir).filter((e) => !ids.has(e.id));
  mkdirSync(devDir, { recursive: true, mode: 0o700 });
  for (const m of all) syncTree(dir, join(devDir, m.id), devDir, rewriteSed);
  // The shell loads the copy, so check the copy, not the tree it came from.
  for (const m of all) {
    const copy = validatePluginDir(join(devDir, m.id));
    if (copy.problems.length > 0) {
      for (const p of copy.problems) err(rt, tr("plugin.invalidPlugin", p));
      return 1;
    }
  }
  writeDevIndex(devDir, [
    ...kept,
    ...all.map((m) =>
      devEntryOf(m, m.manifest === "manifest.json" ? "" : dirname(m.manifest) === "." ? "" : dirname(m.manifest)),
    ),
  ]);
  ok(rt, tr("plugin.devSynced", [...ids].join(", ")));
  try {
    const reply = await rescan();
    if (reply === "disabled") warn(rt, tr("plugin.devShellDisabled"));
  } catch {
    warn(rt, tr("plugin.devShellNotRunning"));
  }
  return 0;
}

let sigint: (() => void) | null = null;

function watchOnce(dir: string): Promise<boolean> {
  return new Promise((resolve) => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const w = watch(dir, { recursive: true }, () => {
      clearTimeout(timer);
      timer = setTimeout(() => {
        w.close();
        resolve(true);
      }, 300);
    });
    if (sigint !== null) process.off("SIGINT", sigint);
    sigint = () => {
      w.close();
      resolve(false);
    };
    process.once("SIGINT", sigint);
  });
}

export async function runPluginDev(
  rt: Runtime,
  dir: string,
  opts: PluginDevOpts = {},
): Promise<number> {
  const enabled = opts.devEnabled ?? shellDevPluginsEnabled();
  if (!enabled) {
    err(rt, tr("plugin.devDisabled"));
    hint(rt, tr("plugin.devEnableHint"));
    return 1;
  }
  warn(rt, DEV_WARNING);
  const devDir = opts.devDir ?? devPluginsDir();
  const shellDir = opts.shellDir !== undefined ? opts.shellDir : shellShareDir();
  const rewriteSed = shellDir === null ? null : join(shellDir, "compat", "rewrite.sed");
  if (rewriteSed === null || !existsSync(rewriteSed)) {
    err(rt, tr("plugin.devNoRewrite"));
    return 1;
  }
  const rescan = opts.rescan ?? (() => shellIpc("rescanPlugins"));

  if (opts.remove === true) {
    if (!isValidPluginId(dir)) {
      err(rt, tr("plugin.devNotLoaded", dir));
      return 1;
    }
    const index = readDevIndex(devDir);
    if (!index.some((e) => e.id === dir)) {
      err(rt, tr("plugin.devNotLoaded", dir));
      return 1;
    }
    writeDevIndex(devDir, index.filter((e) => e.id !== dir));
    assertUnder(devDir, join(devDir, dir));
    rmSync(join(devDir, dir), { recursive: true, force: true });
    ok(rt, tr("plugin.devRemoved", dir));
    await rescan().catch(() => "");
    return 0;
  }

  if (!existsSync(dir)) {
    err(rt, tr("plugin.noSuchDirectory", dir));
    return 1;
  }
  let code = await devOnce(rt, dir, devDir, rewriteSed, rescan);
  if (opts.watch !== true || code !== 0) return code;
  info(rt, tr("plugin.devWatching", dir));
  const wait = opts.waitForChange ?? watchOnce;
  while (await wait(dir)) {
    code = await devOnce(rt, dir, devDir, rewriteSed, rescan);
  }
  return 0;
}
