import {
  flakeUpdateArgv,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  ok,
  info,
  data,
  type Runtime,
} from "@marchyo/core";
import { requireFlake } from "./require-flake.ts";

export type UpdateOpts = { dryRun: boolean };

export async function runUpdate(
  rt: Runtime,
  opts: UpdateOpts,
): Promise<number> {
  const flake = await requireFlake(rt);
  if (!flake) return 2;

  const argv = flakeUpdateArgv(flake.path);
  if (opts.dryRun) {
    const command = formatArgv(argv);
    data(
      rt,
      { command, flake: { path: flake.path, source: flake.source } },
      () => command,
    );
    return 0;
  }

  if (!commandAvailable("nix")) {
    err(rt, "nix not found in PATH");
    return 1;
  }

  info(rt, `updating flake inputs in ${flake.path} (${flake.source}) ...`);
  const code = await runArgv(argv, { noInput: rt.noInput });
  if (code === 0) {
    ok(rt, "flake inputs updated");
    info(rt, "run 'marchyo rebuild' to apply (or 'marchyo upgrade' next time).");
  }
  return code;
}
