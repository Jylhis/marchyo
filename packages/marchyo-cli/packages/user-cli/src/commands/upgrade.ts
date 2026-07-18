import {
  flakeUpdateArgv,
  rebuildArgv,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  info,
  data,
  type Runtime,
} from "@marchyo/core";
import { requireFlake } from "./require-flake.ts";
import { runRebuild } from "./rebuild.ts";

export type UpgradeOpts = { dryRun: boolean };

// upgrade = update inputs + rebuild. Dry-run prints both commands without
// executing either (updating flake.lock is itself a mutation, so unlike
// `rebuild -n` there is no safe partial execution).
export async function runUpgrade(
  rt: Runtime,
  opts: UpgradeOpts,
): Promise<number> {
  const flake = await requireFlake(rt);
  if (!flake) return 2;

  const updateArgv = flakeUpdateArgv(flake.path);
  if (opts.dryRun) {
    const rebuild = rebuildArgv({ flakePath: flake.path, noInput: rt.noInput });
    const commands = [formatArgv(updateArgv), formatArgv(rebuild.argv)];
    data(
      rt,
      { commands, flake: { path: flake.path, source: flake.source } },
      () => commands.join("\n"),
    );
    return 0;
  }

  if (!commandAvailable("nix")) {
    err(rt, "nix not found in PATH");
    return 1;
  }

  info(rt, `updating flake inputs in ${flake.path} (${flake.source}) ...`);
  const updateCode = await runArgv(updateArgv, { noInput: rt.noInput });
  if (updateCode !== 0) {
    err(rt, `nix flake update failed (exit ${updateCode}); skipping rebuild`);
    return updateCode;
  }

  return runRebuild(rt, { dryRun: false });
}
