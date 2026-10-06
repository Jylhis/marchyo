import { join } from "node:path";
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
  reservedPrefixClash,
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

type Manifest = {
  id: string;
  kinds: PluginKind[];
  entryPoints: Record<string, string>;
  name?: string;
  version?: string;
  prefix?: string;
};

const KIND_LIST = Object.keys(PLUGIN_KINDS).join(", ");

// Validate a parsed manifest.json. Returns the manifest, or a message naming
// the first problem. The kind, entry point and prefix rules match
// packages/marchyo-shell/plugin.nix, so a manifest accepted here builds.
export function validateManifest(raw: unknown): Manifest | string {
  if (typeof raw !== "object" || raw === null) return "manifest.json is not an object";
  const m = raw as Record<string, unknown>;
  if (m.schemaVersion !== 1) return "manifest schemaVersion must be 1";
  if (typeof m.id !== "string" || m.id === "") return "manifest id is missing";
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

async function readManifest(treePath: string): Promise<Manifest | string> {
  const file = Bun.file(join(treePath, "manifest.json"));
  if (!(await file.exists())) return "manifest.json missing at the repo root";
  let raw: unknown;
  try {
    raw = JSON.parse(await file.text());
  } catch {
    return "manifest.json is not valid JSON";
  }
  return validateManifest(raw);
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
    err(rt, "nix-prefetch-git not found");
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

  info(rt, `fetching ${url} ...`);
  const pin = await prefetch(url, opts.rev);
  if (pin === null) {
    err(rt, `could not fetch ${url}`);
    hint(rt, "check the URL and revision, and that the host is reachable");
    return 1;
  }

  const manifest = await readManifest(pin.path);
  if (typeof manifest === "string") {
    err(rt, `invalid plugin: ${manifest}`);
    return 1;
  }
  if (manifest.id.startsWith("marchyo.")) {
    err(rt, `plugin id '${manifest.id}' uses the reserved marchyo.* namespace`);
    return 1;
  }

  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.shell?.extraPlugins ?? [];
  if (existing.some((p) => p.id === manifest.id)) {
    err(rt, `plugin '${manifest.id}' is already added`);
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
    err(rt, `plugin '${id}' is not CLI-managed`);
    hint(
      rt,
      "flake-declared plugins live in marchyo.shell.plugins; edit that list instead",
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
    err(rt, "--rev needs a plugin id");
    hint(rt, "Try: marchyo plugin update <id> --rev <rev>");
    return 2;
  }
  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.shell?.extraPlugins ?? [];
  if (id !== undefined && !existing.some((p) => p.id === id)) {
    err(rt, `plugin '${id}' is not CLI-managed`);
    hint(
      rt,
      "see `marchyo plugin list`; flake-declared plugins update with the flake inputs",
    );
    return 1;
  }
  const targets = existing.filter((p) => id === undefined || p.id === id);
  if (targets.length === 0) {
    ok(rt, "no CLI-added plugins to update");
    return 0;
  }
  const prefetch = prefetcher(rt, opts.prefetch, "update");
  if (prefetch === null) return 1;

  const updated = new Map<string, ExtraPlugin>();
  const changes: string[] = [];
  for (const p of targets) {
    info(rt, `fetching ${p.url} ...`);
    const pin = await prefetch(p.url, opts.rev);
    if (pin === null) {
      err(rt, `could not fetch ${p.url}`);
      hint(rt, "check the URL and revision, and that the host is reachable");
      return 1;
    }
    const manifest = await readManifest(pin.path);
    if (typeof manifest === "string") {
      err(rt, `invalid plugin '${p.id}' at ${pin.rev.slice(0, 12)}: ${manifest}`);
      return 1;
    }
    if (manifest.id !== p.id) {
      err(rt, `plugin '${p.id}' now declares id '${manifest.id}'`);
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
      "no plugins.lock.json in the installed shell; showing CLI-added plugins only",
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
