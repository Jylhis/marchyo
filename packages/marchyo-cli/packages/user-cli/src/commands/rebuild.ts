import { nixosRebuild, err, info, type Runtime } from "@marchyo/core";
import { requireFlake } from "./require-flake.ts";

export type RebuildOpts = { dryRun: boolean };

export async function runRebuild(
  rt: Runtime,
  opts: RebuildOpts,
): Promise<number> {
  const flake = await requireFlake(rt);
  if (!flake) return 2;

  info(
    rt,
    `rebuilding from ${flake.path} (${flake.source}, ${
      opts.dryRun ? "dry-activate" : "switch"
    }) ...`,
  );
  const result = await nixosRebuild({
    flakePath: flake.path,
    dryActivate: opts.dryRun,
    noInput: rt.noInput,
  });
  if (result.kind === "unavailable") {
    err(rt, result.message);
    return 1;
  }
  return result.code;
}
