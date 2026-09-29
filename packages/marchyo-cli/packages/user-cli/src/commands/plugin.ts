import { join } from "node:path";
import {
  type Runtime,
  type State,
  captureArgv,
  commandAvailable,
  data,
  err,
  hint,
  info,
  readState,
} from "@marchyo/core";
import { type DeclarativeOpts, persistAndRebuild } from "./declarative.ts";

// `marchyo plugin` — the CLI leg of the build-time (Option A) shell plugin
// platform. A plugin is Nix-declared and baked into the store shell; there is
// no runtime discovery. `add` pins a git source (rev + hash) and mirrors its
// manifest fields into the marchyoCliState sidecar (marchyo.shell.extraPlugins);
// a rebuild builds it via pkgs.mkMarchyoShellPlugin and bakes it in. Hand-written
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
// older ones only `sha256` — accept either.
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
  kinds: string[];
  entryPoints: Record<string, string>;
  name?: string;
  version?: string;
};

async function readManifest(treePath: string): Promise<Manifest | string> {
  const file = Bun.file(join(treePath, "manifest.json"));
  if (!(await file.exists())) return "manifest.json missing at the repo root";
  let raw: unknown;
  try {
    raw = JSON.parse(await file.text());
  } catch {
    return "manifest.json is not valid JSON";
  }
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
  if (
    typeof m.entryPoints !== "object" ||
    m.entryPoints === null ||
    Object.keys(m.entryPoints).length === 0 ||
    !Object.values(m.entryPoints).every((v) => typeof v === "string")
  )
    return "manifest entryPoints must map each kind to a QML file";
  return {
    id: m.id,
    kinds: m.kinds as string[],
    entryPoints: m.entryPoints as Record<string, string>,
    ...(typeof m.name === "string" ? { name: m.name } : {}),
    ...(typeof m.version === "string" ? { version: m.version } : {}),
  };
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
  const prefetch = opts.prefetch ?? defaultPrefetch;
  if (opts.prefetch === undefined && !commandAvailable("nix-prefetch-git")) {
    err(rt, "nix-prefetch-git not found");
    hint(rt, "Try: nix shell nixpkgs#nix-prefetch-git -c marchyo plugin add …");
    return 1;
  }

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

  const entry: ExtraPlugin = {
    id: manifest.id,
    url,
    rev: pin.rev,
    hash: pin.hash,
    kinds: manifest.kinds,
    entryPoints: manifest.entryPoints,
    ...(manifest.name !== undefined ? { name: manifest.name } : {}),
    ...(manifest.version !== undefined ? { version: manifest.version } : {}),
  };
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
      "flake-declared plugins live in marchyo.shell.plugins — edit that list instead",
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

export async function runPluginList(rt: Runtime): Promise<number> {
  const state = await readState().catch(() => ({}) as State);
  const plugins = state.shell?.extraPlugins ?? [];
  data(rt, { plugins }, () => {
    if (plugins.length === 0) return "no CLI-added plugins";
    return plugins
      .map((p) => `${p.id}\t${p.kinds.join(",")}\t${p.url}@${p.rev.slice(0, 12)}`)
      .join("\n");
  });
  return 0;
}
