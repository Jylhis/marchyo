import {
  ThemeVariant,
  readState,
  writeState,
  mergeState,
  detectFlake,
  nixosRebuild,
  ok,
  err,
  info,
  data,
  usageError,
  type Runtime,
  type State,
} from "@marchyo/core";

export async function runThemeGet(rt: Runtime): Promise<number> {
  const state = await readState().catch(() => ({}) as State);
  const variant = state.theme?.variant ?? null;
  data(rt, { theme: { variant } }, () =>
    variant ?? "(unset, falling back to flake default)",
  );
  return 0;
}

export type ThemeSetOpts = { rebuild: boolean };

export async function runThemeSet(
  rt: Runtime,
  variant: string,
  opts: ThemeSetOpts,
): Promise<number> {
  const parsed = ThemeVariant.safeParse(variant);
  if (!parsed.success) {
    return usageError(
      rt,
      `invalid theme variant: "${variant}"`,
      `marchyo theme set dark   (allowed: dark, light)`,
    );
  }

  const prev = await readState().catch(() => ({}) as State);
  const next = mergeState(prev, { theme: { variant: parsed.data } });
  try {
    await writeState(next);
  } catch (e) {
    if (e instanceof Error && e.message.includes("EACCES")) {
      err(rt, "cannot write /etc/marchyo/cli-state.json");
      return 1;
    }
    throw e;
  }

  ok(rt, `theme.variant set to '${parsed.data}'`);
  data(rt, { theme: { variant: parsed.data } }, () => parsed.data);

  if (!opts.rebuild) {
    info(rt, "run 'marchyo rebuild' to apply.");
    return 0;
  }

  const flake = await detectFlake();
  if (!flake) {
    return usageError(
      rt,
      "could not detect flake",
      "place a flake at /etc/nixos/flake.nix or run from a flake directory",
    );
  }
  info(rt, `rebuilding from ${flake.path} ...`);
  return await nixosRebuild({ flakePath: flake.path });
}
