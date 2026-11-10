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
  tr,
} from "@marchyo/core";

export type GcOpts = { olderThan: string; dryRun: boolean };

export async function runGc(rt: Runtime, opts: GcOpts): Promise<number> {
  const period = parseGcPeriod(opts.olderThan);
  if (period === null) {
    return usageError(
      rt,
      tr("gc.invalidPeriodExpectedDays", opts.olderThan),
      "marchyo gc --delete-older-than 30d",
    );
  }

  const { argv, needsSudo } = gcArgv(period, { noInput: rt.noInput });

  if (opts.dryRun) {
    const command = formatArgv(argv);
    data(rt, { command, olderThan: period }, () => command);
    return 0;
  }

  if (needsSudo && !commandAvailable("sudo")) {
    err(
      rt,
      tr("gc.collectingSystemGenerationsRequiresRoot"),
    );
    return 1;
  }
  if (!needsSudo && !commandAvailable("nix-collect-garbage")) {
    err(rt, tr("gc.nixCollectGarbageNotFound"));
    return 1;
  }

  info(rt, tr("gc.collectingGarbageOlderThan", period));
  const code = await runArgv(argv, { noInput: rt.noInput });
  if (code === 0) ok(rt, tr("gc.garbageCollectionFinished"));
  return code;
}
