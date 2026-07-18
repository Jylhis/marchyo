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
    const command = formatArgv(argv);
    data(rt, { command }, () => command);
    return 0;
  }

  if (needsSudo && !commandAvailable("sudo")) {
    err(
      rt,
      "rollback requires root; install sudo or re-run as root (e.g. `sudo marchyo rollback`)",
    );
    return 1;
  }
  if (!needsSudo && !commandAvailable("nixos-rebuild")) {
    err(rt, "nixos-rebuild not found in PATH");
    return 1;
  }

  info(rt, "rolling back to the previous system generation ...");
  return await runArgv(argv, { noInput: rt.noInput });
}
