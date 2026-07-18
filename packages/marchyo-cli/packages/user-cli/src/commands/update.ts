import {
  detectFlake,
  flakeUpdateArgv,
  formatArgv,
  runArgv,
  ok,
  info,
  data,
  usageError,
  type Runtime,
} from "@marchyo/core";

export type UpdateOpts = { dryRun: boolean };

export async function runUpdate(
  rt: Runtime,
  opts: UpdateOpts,
): Promise<number> {
  const flake = await detectFlake();
  if (!flake) {
    return usageError(
      rt,
      "could not detect flake",
      "place a flake at /etc/nixos/flake.nix or run from a flake directory",
    );
  }

  const argv = flakeUpdateArgv(flake.path);
  if (opts.dryRun) {
    data(
      rt,
      { command: formatArgv(argv), flake: { path: flake.path, source: flake.source } },
      () => formatArgv(argv),
    );
    return 0;
  }

  info(rt, `updating flake inputs in ${flake.path} (${flake.source}) ...`);
  const code = await runArgv(argv, { noInput: rt.noInput });
  if (code === 0) {
    ok(rt, "flake inputs updated");
    info(rt, "run 'marchyo rebuild' to apply (or 'marchyo upgrade' next time).");
  }
  return code;
}
