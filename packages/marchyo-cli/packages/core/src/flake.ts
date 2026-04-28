import { $ } from "bun";
import { existsSync } from "node:fs";
import { readState, writeState, mergeState } from "./state.ts";

const FLAKE_CANDIDATES = ["/etc/nixos/flake.nix", "/etc/nixos"];

export type FlakeLocation = {
  path: string;
  source: "cached" | "etc-nixos" | "cwd" | "explicit";
};

export async function detectFlake(): Promise<FlakeLocation | null> {
  const state = await readState().catch(() => null);
  const cached = state?._flake?.path;
  if (cached && existsSync(cached)) {
    return { path: cached, source: "cached" };
  }

  for (const candidate of FLAKE_CANDIDATES) {
    if (existsSync(candidate)) {
      const path = candidate.endsWith("flake.nix")
        ? candidate.replace(/\/flake\.nix$/, "")
        : candidate;
      if (existsSync(`${path}/flake.nix`)) {
        return { path, source: "etc-nixos" };
      }
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
};

export async function nixosRebuild(opts: RebuildOptions): Promise<number> {
  const subcommand = opts.dryActivate ? "dry-activate" : "switch";
  const flakeRef = opts.hostname
    ? `${opts.flakePath}#${opts.hostname}`
    : opts.flakePath;
  // --impure is required for the cli-state module to read
  // /etc/marchyo/cli-state.json from outside the flake source tree.
  const proc = Bun.spawn(
    ["sudo", "nixos-rebuild", subcommand, "--impure", "--flake", flakeRef],
    { stdout: "inherit", stderr: "inherit", stdin: "inherit" },
  );
  return await proc.exited;
}
