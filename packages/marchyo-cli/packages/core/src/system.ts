import { readdirSync, readlinkSync } from "node:fs";
import { join } from "node:path";
import { userInfo } from "node:os";

// Argv builders + spawn helper for the declarative system subcommands
// (update / upgrade / rollback / gc / diff). The builders are pure so the
// exact command strings are unit-testable; the commands print them under
// --dry-run and execute them otherwise.

// Render an argv for display (dry-run output, info lines). Quotes only
// arguments that need it so common commands read naturally.
export function formatArgv(argv: string[]): string {
  return argv
    .map((a) => (/[\s'"\\$]/.test(a) || a === "" ? JSON.stringify(a) : a))
    .join(" ");
}

// `nix flake update` run against the detected flake directory.
export function flakeUpdateArgv(flakePath: string): string[] {
  return ["nix", "flake", "update", "--flake", flakePath];
}

// `nixos-rebuild switch --rollback`, sudo-wrapped exactly like
// flake.ts:rebuildArgv (root -> bare, --no-input -> sudo -n, else sudo).
export function rollbackArgv(
  opts: { noInput?: boolean } = {},
  isRoot: boolean = userInfo().uid === 0,
): { argv: string[]; needsSudo: boolean } {
  const inner = ["nixos-rebuild", "switch", "--rollback"];
  if (isRoot) return { argv: inner, needsSudo: false };
  if (opts.noInput) return { argv: ["sudo", "-n", ...inner], needsSudo: true };
  return { argv: ["sudo", ...inner], needsSudo: true };
}

// Validate a nix-collect-garbage --delete-older-than period ("14d", "30d").
// nix only accepts whole days; returns the normalized period or null.
export function parseGcPeriod(raw: string): string | null {
  return /^\d+d$/.test(raw) ? raw : null;
}

// `nix-collect-garbage --delete-older-than <period>`, sudo-wrapped so old
// *system* generations are collected too (an unprivileged run only touches
// the calling user's profiles).
export function gcArgv(
  olderThan: string,
  opts: { noInput?: boolean } = {},
  isRoot: boolean = userInfo().uid === 0,
): { argv: string[]; needsSudo: boolean } {
  const inner = ["nix-collect-garbage", "--delete-older-than", olderThan];
  if (isRoot) return { argv: inner, needsSudo: false };
  if (opts.noInput) return { argv: ["sudo", "-n", ...inner], needsSudo: true };
  return { argv: ["sudo", ...inner], needsSudo: true };
}

export const SYSTEM_PROFILES_DIR = "/nix/var/nix/profiles";

export type Generation = {
  number: number;
  path: string;
  // Symlink target (store path) when resolvable, else null.
  target: string | null;
};

// List system generations (system-<N>-link entries) sorted oldest-first.
// Returns [] when the profiles directory is missing (non-NixOS host).
export function listSystemGenerations(
  profilesDir: string = SYSTEM_PROFILES_DIR,
): Generation[] {
  let entries: string[];
  try {
    entries = readdirSync(profilesDir);
  } catch {
    return [];
  }
  const gens: Generation[] = [];
  for (const entry of entries) {
    const match = entry.match(/^system-(\d+)-link$/);
    if (!match?.[1]) continue;
    const path = join(profilesDir, entry);
    let target: string | null = null;
    try {
      target = readlinkSync(path);
    } catch {
      // dangling or unreadable link; keep target null
    }
    gens.push({ number: Number(match[1]), path, target });
  }
  return gens.sort((a, b) => a.number - b.number);
}

export type DiffTargets = {
  left: string;
  right: string;
  reason: "current-vs-newest" | "previous-vs-newest";
};

// Decide what `marchyo diff` compares (mirrors update-diff.nix, which runs
// `dix /run/current-system <incoming>`):
//   - a newer generation than the running system exists -> current vs newest
//     (e.g. `nixos-rebuild boot` was run but not yet activated)
//   - the running system IS the newest generation -> previous vs newest
//     (what did the last rebuild change)
//   - fewer than two distinct states -> null (nothing to diff)
export function pickDiffTargets(
  currentTarget: string | null,
  generations: Generation[],
  currentPath = "/run/current-system",
): DiffTargets | null {
  const newest = generations[generations.length - 1];
  if (!newest) return null;
  if (currentTarget !== null && newest.target !== currentTarget) {
    return {
      left: currentPath,
      right: newest.path,
      reason: "current-vs-newest",
    };
  }
  const previous = generations[generations.length - 2];
  if (!previous) return null;
  return {
    left: previous.path,
    right: newest.path,
    reason: "previous-vs-newest",
  };
}

// Spawn an argv with inherited stdio, returning its exit code. Used by the
// system subcommands after the dry-run branch has been handled.
export async function runArgv(
  argv: string[],
  opts: { noInput?: boolean; cwd?: string } = {},
): Promise<number> {
  const proc = Bun.spawn(argv, {
    cwd: opts.cwd,
    stdout: "inherit",
    stderr: "inherit",
    stdin: opts.noInput ? "ignore" : "inherit",
  });
  return await proc.exited;
}
