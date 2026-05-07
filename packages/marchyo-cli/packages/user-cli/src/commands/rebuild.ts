import {
  detectFlake,
  nixosRebuild,
  info,
  usageError,
  type Runtime,
} from "@marchyo/core";

export type RebuildOpts = { dryRun: boolean };

export async function runRebuild(
  rt: Runtime,
  opts: RebuildOpts,
): Promise<number> {
  const flake = await detectFlake();
  if (!flake) {
    return usageError(
      rt,
      "could not detect flake",
      "place a flake at /etc/nixos/flake.nix or run from a flake directory",
    );
  }

  info(
    rt,
    `rebuilding from ${flake.path} (${flake.source}, ${
      opts.dryRun ? "dry-activate" : "switch"
    }) ...`,
  );
  return await nixosRebuild({
    flakePath: flake.path,
    dryActivate: opts.dryRun,
  });
}
