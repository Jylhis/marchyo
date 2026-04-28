import {
  ThemeVariant,
  readState,
  writeState,
  mergeState,
  detectFlake,
  nixosRebuild,
} from "@marchyo/core";

export type ThemeOpts = { rebuild: boolean };

export async function runTheme(variant: string, opts: ThemeOpts): Promise<void> {
  const parsed = ThemeVariant.safeParse(variant);
  if (!parsed.success) {
    console.error(`error: variant must be 'dark' or 'light' (got '${variant}')`);
    process.exit(1);
  }

  const prev = await readState();
  const next = mergeState(prev, { theme: { variant: parsed.data } });
  try {
    await writeState(next);
  } catch (err) {
    if (err instanceof Error && err.message.includes("EACCES")) {
      console.error(
        "error: cannot write /etc/marchyo/cli-state.json — re-run with sudo",
      );
      process.exit(1);
    }
    throw err;
  }

  console.log(`theme.variant set to '${parsed.data}'`);

  if (opts.rebuild) {
    const flake = await detectFlake();
    if (!flake) {
      console.error("error: could not detect flake; pass --flake or set _flake.path in state");
      process.exit(1);
    }
    console.log(`rebuilding from ${flake.path} ...`);
    const code = await nixosRebuild({ flakePath: flake.path });
    process.exit(code);
  } else {
    console.log("run 'marchyo rebuild' to apply.");
  }
}
