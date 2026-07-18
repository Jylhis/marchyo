import {
  parseGcPeriod,
  gcArgv,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  ok,
  info,
  data,
  usageError,
  type Runtime,
} from "@marchyo/core";

export type GcOpts = { olderThan: string; dryRun: boolean };

export async function runGc(rt: Runtime, opts: GcOpts): Promise<number> {
  const period = parseGcPeriod(opts.olderThan);
  if (period === null) {
    return usageError(
      rt,
      `invalid period: "${opts.olderThan}" (expected <days>d, e.g. 14d)`,
      "marchyo gc --delete-older-than 30d",
    );
  }

  const { argv, needsSudo } = gcArgv(period, { noInput: rt.noInput });

  if (opts.dryRun) {
    data(rt, { command: formatArgv(argv), olderThan: period }, () =>
      formatArgv(argv),
    );
    return 0;
  }

  if (needsSudo && !commandAvailable("sudo")) {
    err(
      rt,
      "collecting system generations requires root; install sudo or re-run as root (e.g. `sudo marchyo gc`)",
    );
    return 2;
  }

  info(rt, `collecting garbage older than ${period} ...`);
  const code = await runArgv(argv, { noInput: rt.noInput });
  if (code === 0) ok(rt, "garbage collection finished");
  return code;
}
