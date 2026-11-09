import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";
import {
  type PluginKind,
  type PluginLock,
  type Runtime,
  type State,
  PLUGIN_KINDS,
  captureArgv,
  commandAvailable,
  data,
  err,
  hint,
  info,
  isPluginKind,
  ok,
  readPluginLock,
  readState,
  reservedIdNamespace,
  reservedPrefixClash,
  tr,
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
};

const KIND_LIST = Object.keys(PLUGIN_KINDS).join(", ");

// Same shape packages/marchyo-shell/plugin.nix accepts: the id names a
// directory under the shell's plugins/ tree.
export function isValidPluginId(id: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) && !id.includes("..");
}

// Validate a parsed manifest.json. Returns the manifest, or a message naming
// the first problem. The kind, entry point and prefix rules match
// packages/marchyo-shell/plugin.nix, so a manifest accepted here builds.
export function validateManifest(raw: unknown): Manifest | string {
  if (typeof raw !== "object" || raw === null) return "manifest.json is not an object";
  const m = raw as Record<string, unknown>;
  if (m.schemaVersion !== 1) return "manifest schemaVersion must be 1";
  if (typeof m.id !== "string" || m.id === "") return "manifest id is missing";
  if (!isValidPluginId(m.id))
    return `plugin id '${m.id}' must match [A-Za-z0-9][A-Za-z0-9._-]* and not contain '..'`;
  const ns = reservedIdNamespace(m.id);
  if (ns !== null)
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
  return {
    id: m.id,
    kinds: kinds as PluginKind[],
    entryPoints,
    ...(typeof m.name === "string" ? { name: m.name } : {}),
    ...(typeof m.version === "string" ? { version: m.version } : {}),
    ...(prefix !== undefined ? { prefix } : {}),
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
  problems: string[];
};

// The plugin.nix build checks, run on a checkout: manifest.json validates,
// its entry points exist and no symlink is inside. Every problem is reported,
// not just the first.
export function validatePluginDir(dir: string): PluginDirReport {
  const problems: string[] = [];
  const report: PluginDirReport = { manifest: null, problems };
  if (!existsSync(join(dir, "manifest.json"))) {
    problems.push("manifest.json missing at the plugin root");
    return report;
  }
  const { files, links } = walk(dir);
  for (const l of links) problems.push(`symlink not allowed: ${l}`);

  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(join(dir, "manifest.json"), "utf8"));
  } catch {
    problems.push("manifest.json: not valid JSON");
    return report;
  }
  const v = validateManifest(raw);
  if (typeof v === "string") {
    problems.push(`manifest.json: ${v}`);
    return report;
  }
  report.manifest = v;
  for (const ep of Object.values(v.entryPoints)) {
    if (!safeRel(ep)) problems.push(`manifest.json: unsafe entry point path '${ep}'`);
    else if (!files.includes(ep)) problems.push(`manifest.json: entry point '${ep}' does not exist`);
  }
  return report;
}

// Validate a fetched tree the way the build does (manifest.json, entry points,
// symlinks); a message naming the first problem when it does not.
function readManifest(treePath: string): Manifest | string {
  const report = validatePluginDir(treePath);
  if (report.problems.length > 0 || report.manifest === null)
    return report.problems[0] ?? "manifest.json missing at the repo root";
  return report.manifest;
}

// The state entry for a pinned source and its manifest.
function toEntry(url: string, pin: PluginPin, manifest: Manifest): ExtraPlugin {
  return {
    id: manifest.id,
    url,
    rev: pin.rev,
    hash: pin.hash,
    kinds: manifest.kinds,
    entryPoints: manifest.entryPoints,
    ...(manifest.name !== undefined ? { name: manifest.name } : {}),
    ...(manifest.version !== undefined ? { version: manifest.version } : {}),
    ...(manifest.prefix !== undefined ? { prefix: manifest.prefix } : {}),
  };
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

  const manifest = readManifest(pin.path);
  if (typeof manifest === "string") {
    err(rt, tr("plugin.invalidPlugin", manifest));
    return 1;
  }

  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.shell?.extraPlugins ?? [];
  if (existing.some((p) => p.id === manifest.id)) {
    err(rt, tr("plugin.pluginIsAlreadyAdded", manifest.id));
    hint(rt, `Try: marchyo plugin remove ${manifest.id} first`);
    return 1;
  }

  const entry = toEntry(url, pin, manifest);
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
    const manifest = readManifest(pin.path);
    if (typeof manifest === "string") {
      err(rt, tr("plugin.invalidPluginAt", p.id, pin.rev.slice(0, 12), manifest));
      return 1;
    }
    if (manifest.id !== p.id) {
      err(rt, tr("plugin.pluginNowDeclaresId", p.id, manifest.id));
      hint(rt, `Try: marchyo plugin remove ${p.id}, then marchyo plugin add ${p.url}`);
      return 1;
    }
    const next = toEntry(p.url, pin, manifest);
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

// `marchyo plugin validate <dir>`: the plugin.nix build checks on a checkout.
export async function runPluginValidate(rt: Runtime, dir: string): Promise<number> {
  if (!existsSync(dir)) {
    err(rt, tr("plugin.noSuchDirectory", dir));
    return 1;
  }
  const report = validatePluginDir(dir);
  data(rt, report, () =>
    report.problems.length === 0
      ? `ok: ${report.manifest?.id}`
      : report.problems.map((p) => `invalid: ${p}`).join("\n"),
  );
  return report.problems.length === 0 ? 0 : 1;
}
