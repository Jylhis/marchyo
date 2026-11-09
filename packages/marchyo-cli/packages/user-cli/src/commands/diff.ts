import { readlinkSync } from "node:fs";
import {
  listSystemGenerations,
  pickDiffTargets,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  hint,
  info,
  data,
  type Runtime,
  tr,
} from "@marchyo/core";

export type DiffOpts = { dryRun: boolean };

const CURRENT_SYSTEM = "/run/current-system";

// Compare system closures with dix, mirroring update-diff.nix (which runs
// `dix diff /run/current-system <incoming>` as a pre-switch check): when a
// generation newer than the running system exists we diff against it,
// otherwise we diff the last two generations.
export async function runDiff(rt: Runtime, opts: DiffOpts): Promise<number> {
  const generations = listSystemGenerations();
  if (generations.length === 0) {
    err(rt, tr("diff.noSystemGenerationsFoundUnder"));
    hint(rt, tr("diff.isThisNixosSystem"));
    return 1;
  }

  let currentTarget: string | null = null;
  try {
    currentTarget = readlinkSync(CURRENT_SYSTEM);
  } catch {
    // not activated / non-NixOS; fall back to the last two generations
  }

  const targets = pickDiffTargets(currentTarget, generations, CURRENT_SYSTEM);
  if (!targets) {
    info(rt, tr("diff.onlyOneSystemGenerationExists"));
    return 0;
  }

  const argv = ["dix", "diff", targets.left, targets.right];
  if (opts.dryRun) {
    const command = formatArgv(argv);
    data(rt, { command, ...targets }, () => command);
    return 0;
  }

  if (!commandAvailable("dix")) {
    err(rt, tr("diff.dixNotFoundInPath"));
    hint(rt, tr("diff.dixShipsWithMarchyoModules"));
    return 1;
  }

  info(rt, tr("diff.diffing", targets.left, targets.right, targets.reason));
  return await runArgv(argv, { noInput: rt.noInput });
}
