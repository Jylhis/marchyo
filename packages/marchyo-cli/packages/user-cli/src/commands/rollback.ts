import {
  rollbackArgv,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  info,
  data,
  type Runtime,
  tr,
} from "@marchyo/core";

export type RollbackOpts = { dryRun: boolean };

export async function runRollback(
  rt: Runtime,
  opts: RollbackOpts,
): Promise<number> {
  const { argv, needsSudo } = rollbackArgv({ noInput: rt.noInput });

  if (opts.dryRun) {
    const command = formatArgv(argv);
    data(rt, { command }, () => command);
    return 0;
  }

  if (needsSudo && !commandAvailable("sudo")) {
    err(
      rt,
      tr("rollback.rollbackRequiresRootInstallSudo"),
    );
    return 1;
  }
  if (!needsSudo && !commandAvailable("nixos-rebuild")) {
    err(rt, tr("rollback.nixosRebuildNotFoundIn"));
    return 1;
  }

  info(rt, tr("rollback.rollingBackToThePrevious"));
  return await runArgv(argv, { noInput: rt.noInput });
}
