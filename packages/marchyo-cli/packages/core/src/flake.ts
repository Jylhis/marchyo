import { existsSync } from "node:fs";
import { userInfo } from "node:os";
import { readState, writeState, mergeState } from "./state.ts";

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
  | { kind: "needs-sudo"; message: string };

// Build the argv for nixos-rebuild, choosing whether to wrap in sudo based
// on the current uid and the noInput flag (jylhis/design §2.5.1: never
// prompt under --no-input / CI=1). Returns the argv plus a sentinel if a
// non-interactive sudo escalation cannot proceed.
function rebuildArgv(opts: RebuildOptions): {
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

  const isRoot = userInfo().uid === 0;
  if (isRoot) return { argv: inner, needsSudo: false };
  if (opts.noInput) return { argv: ["sudo", "-n", ...inner], needsSudo: true };
  return { argv: ["sudo", ...inner], needsSudo: true };
}

export async function nixosRebuild(opts: RebuildOptions): Promise<RebuildResult> {
  const { argv, needsSudo } = rebuildArgv(opts);

  if (needsSudo && !commandAvailable("sudo")) {
    return {
      kind: "needs-sudo",
      message:
        "rebuild requires root; install sudo or re-run as root (e.g. `sudo marchyo rebuild`)",
    };
  }

  const proc = Bun.spawn(argv, {
    stdout: "inherit",
    stderr: "inherit",
    stdin: opts.noInput ? "ignore" : "inherit",
  });
  return { kind: "ok", code: await proc.exited };
}

function commandAvailable(name: string): boolean {
  const PATH = process.env.PATH ?? "";
  for (const dir of PATH.split(":")) {
    if (dir === "") continue;
    if (existsSync(`${dir}/${name}`)) return true;
  }
  return false;
}
