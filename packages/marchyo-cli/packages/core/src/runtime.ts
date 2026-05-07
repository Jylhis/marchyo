export type Format = "text" | "json";

export type Runtime = {
  format: Format;
  noColor: boolean;
  plain: boolean;
  noAnimation: boolean;
  noInput: boolean;
  quiet: boolean;
  verbose: number;
};

export type RuntimeFlags = {
  format?: string;
  noColor?: boolean;
  plain?: boolean;
  noAnimation?: boolean;
  noInput?: boolean;
  quiet?: boolean;
  verbose?: number;
};

// Honors the canonical color-precedence chain:
//   1. NO_COLOR set       -> off
//   2. --no-color flag    -> off
//   3. --plain flag       -> off (also implies no-animation)
//   4. CLICOLOR_FORCE / FORCE_COLOR / --color=always -> on
//   5. CI env             -> noInput
//   6. !TTY on stdout     -> off (and noAnimation)
export function buildRuntime(
  flags: RuntimeFlags = {},
  env: NodeJS.ProcessEnv = process.env,
  isTTY: boolean = Boolean(process.stdout.isTTY),
): Runtime {
  const format: Format = flags.format === "json" ? "json" : "text";

  const envNoColor = env.NO_COLOR !== undefined && env.NO_COLOR !== "";
  const envForceColor =
    (env.CLICOLOR_FORCE !== undefined && env.CLICOLOR_FORCE !== "0") ||
    (env.FORCE_COLOR !== undefined &&
      env.FORCE_COLOR !== "" &&
      env.FORCE_COLOR !== "0");

  const noColor =
    flags.noColor === true ||
    flags.plain === true ||
    envNoColor ||
    (!envForceColor && !isTTY);

  const plain = flags.plain === true;

  const noAnimation = flags.noAnimation === true || plain || !isTTY;

  const noInput =
    flags.noInput === true || (env.CI !== undefined && env.CI !== "");

  // Apply the no-color decision globally so any library reading these env
  // vars (chalk/ink/etc.) sees the right state. Must happen before Ink mounts.
  if (noColor) env.NO_COLOR = "1";

  return {
    format,
    noColor,
    plain,
    noAnimation,
    noInput,
    quiet: flags.quiet === true,
    verbose: flags.verbose ?? 0,
  };
}
