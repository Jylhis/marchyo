import { readFileSync } from "node:fs";
import {
  captureArgv,
  compareRevs,
  flakeUpdateArgv,
  lockedNixpkgsRev,
  formatArgv,
  runArgv,
  commandAvailable,
  err,
  ok,
  info,
  data,
  type Runtime,
  tr,
} from "@marchyo/core";
import { requireFlake } from "./require-flake.ts";

export type UpdateOpts = { dryRun: boolean; check?: boolean };

function readOrEmpty(path: string): string {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

// The nixpkgs rev pinned in the flake's lock file.
export function pinnedNixpkgsRev(flakePath: string): string {
  return lockedNixpkgsRev(readOrEmpty(`${flakePath}/flake.lock`));
}

// `marchyo update --check`: compare the nixpkgs rev pinned in the flake lock
// with the running system's (`nixos-version --revision`). Read-only and local:
// it never touches the network or the lock file.
async function runUpdateCheck(rt: Runtime): Promise<number> {
  const flake = await requireFlake(rt);
  if (!flake) return 2;
  const running = (await captureArgv(["nixos-version", "--revision"])).stdout.trim();
  const result = compareRevs(pinnedNixpkgsRev(flake.path), running);
  data(rt, result, () =>
    result.available
      ? `update available: flake pins ${result.locked.slice(0, 12)}, system runs ${result.running.slice(0, 12)}`
      : "system matches the flake lock",
  );
  return 0;
}

export async function runUpdate(
  rt: Runtime,
  opts: UpdateOpts,
): Promise<number> {
  if (opts.check) return runUpdateCheck(rt);

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
    err(rt, tr("update.nixNotFoundInPath"));
    return 1;
  }

  info(rt, tr("update.updatingFlakeInputsIn", flake.path, flake.source));
  const code = await runArgv(argv, { noInput: rt.noInput });
  if (code === 0) {
    ok(rt, tr("update.flakeInputsUpdated"));
    info(rt, tr("update.runMarchyoRebuildToApply"));
  }
  return code;
}
