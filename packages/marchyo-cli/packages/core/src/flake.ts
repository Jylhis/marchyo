import { existsSync } from "node:fs";
import { readState, writeState, mergeState } from "./state.ts";
import { sudoWrap } from "./system.ts";

const FLAKE_CANDIDATES = ["/etc/nixos/flake.nix", "/etc/nixos"];

export type FlakeLocation = {
  path: string;
  source: "cached" | "etc-nixos" | "cwd" | "explicit";
};

export async function detectFlake(): Promise<FlakeLocation | null> {
  const state = await readState().catch(() => null);
  const cached = state?._flake?.path;
  if (cached && existsSync(`${cached}/flake.nix`)) {
    return { path: cached, source: "cached" };
  }

  for (const candidate of FLAKE_CANDIDATES) {
    const path = candidate.endsWith("flake.nix")
      ? candidate.replace(/\/flake\.nix$/, "")
      : candidate;
    if (existsSync(`${path}/flake.nix`)) {
      return { path, source: "etc-nixos" };
    }
  }

  if (existsSync(`${process.cwd()}/flake.nix`)) {
    return { path: process.cwd(), source: "cwd" };
  }

  return null;
}

export async function rememberFlake(path: string): Promise<void> {
  const prev = await readState().catch(() => ({}));
  const next = mergeState(prev, { _flake: { path } });
  await writeState(next);
}

export type RebuildOptions = {
  flakePath: string;
  hostname?: string;
  dryActivate?: boolean;
  noInput?: boolean;
};

export type RebuildResult =
  | { kind: "ok"; code: number }
  | { kind: "unavailable"; message: string };

// Build the argv for nixos-rebuild, sudo-wrapped via system.ts:sudoWrap
// based on the current uid and the noInput flag (jylhis/design §2.5.1:
// never prompt under --no-input / CI=1).
export function rebuildArgv(opts: RebuildOptions): {
  argv: string[];
  needsSudo: boolean;
} {
  const subcommand = opts.dryActivate ? "dry-activate" : "switch";
  const flakeRef = opts.hostname
    ? `${opts.flakePath}#${opts.hostname}`
    : opts.flakePath;
  // --impure is required so end-user flakes can read their own
  // /etc/marchyo/cli-state.json overlay (see options.nix persistedState).
  const inner = ["nixos-rebuild", subcommand, "--impure", "--flake", flakeRef];
  return sudoWrap(inner, { noInput: opts.noInput });
}

export async function nixosRebuild(opts: RebuildOptions): Promise<RebuildResult> {
  const { argv, needsSudo } = rebuildArgv(opts);

  if (needsSudo && !commandAvailable("sudo")) {
    return {
      kind: "unavailable",
      message:
        "rebuild requires root; install sudo or re-run as root (e.g. `sudo marchyo rebuild`)",
    };
  }
  const program = argv[0] ?? "";
  if (!commandAvailable(program)) {
    // Guard the spawn: Bun.spawn throws ENOENT on a missing executable.
    return { kind: "unavailable", message: `${program} not found in PATH` };
  }

  const proc = Bun.spawn(argv, {
    stdout: "inherit",
    stderr: "inherit",
    stdin: opts.noInput ? "ignore" : "inherit",
  });
  return { kind: "ok", code: await proc.exited };
}

export function commandAvailable(name: string): boolean {
  const PATH = process.env.PATH ?? "";
  for (const dir of PATH.split(":")) {
    if (dir === "") continue;
    if (existsSync(`${dir}/${name}`)) return true;
  }
  return false;
}
