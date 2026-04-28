import { detectFlake, nixosRebuild } from "@marchyo/core";

export type RebuildOpts = { dry: boolean };

export async function runRebuild(opts: RebuildOpts): Promise<void> {
  const flake = await detectFlake();
  if (!flake) {
    console.error(
      "error: could not detect flake. Place one at /etc/nixos/flake.nix or run from a flake directory.",
    );
    process.exit(1);
  }

  console.log(
    `rebuilding from ${flake.path} (${flake.source}, ${opts.dry ? "dry" : "switch"}) ...`,
  );
  const code = await nixosRebuild({
    flakePath: flake.path,
    dryActivate: opts.dry,
  });
  process.exit(code);
}
