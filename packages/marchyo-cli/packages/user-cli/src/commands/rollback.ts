import {
  rollbackArgv,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  info,
  data,
  type Runtime,
} from "@marchyo/core";

export type RollbackOpts = { dryRun: boolean };

export async function runRollback(
  rt: Runtime,
  opts: RollbackOpts,
): Promise<number> {
  const { argv, needsSudo } = rollbackArgv({ noInput: rt.noInput });

  if (opts.dryRun) {
    data(rt, { command: formatArgv(argv) }, () => formatArgv(argv));
    return 0;
  }

  if (needsSudo && !commandAvailable("sudo")) {
    err(
      rt,
      "rollback requires root; install sudo or re-run as root (e.g. `sudo marchyo rollback`)",
    );
    return 2;
  }

  info(rt, "rolling back to the previous system generation ...");
  return await runArgv(argv, { noInput: rt.noInput });
}
