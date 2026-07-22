// Argv builders for the desktop actuators the runtime-first change model
// drives (hyprctl / makoctl / systemctl --user / notify-send / awww).
// Pure builders keep the exact command strings unit-testable; commands run
// them through system.ts:runArgv (or an injected exec in tests).
//
// The reload vocabulary deliberately mirrors modules/home/theme-runtime.nix:
//  - hyprland: per-keyword `hyprctl keyword` — NEVER `hyprctl reload`,
//    which re-reads the build-time config and reverts runtime keywords
//  - waybar: full `systemctl --user try-restart` — SIGUSR2 spawns duplicates
//  - mako: `makoctl reload`

// hyprctl only works inside a live Hyprland session.
export function hyprlandAvailable(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  const sig = env.HYPRLAND_INSTANCE_SIGNATURE;
  return typeof sig === "string" && sig !== "";
}

export function hyprctlKeywordArgv(keyword: string, value: string): string[] {
  return ["hyprctl", "keyword", keyword, value];
}

export function hyprctlDispatchArgv(...args: string[]): string[] {
  return ["hyprctl", "dispatch", ...args];
}

export function hyprctlGetOptionArgv(option: string): string[] {
  return ["hyprctl", "getoption", "-j", option];
}

export function makoctlArgv(...args: string[]): string[] {
  return ["makoctl", ...args];
}

export function systemctlUserArgv(action: string, unit: string): string[] {
  return ["systemctl", "--user", action, unit];
}

// Low-urgency marchyo-branded notification (theme-runtime.nix's
// `notify-send -u low -a marchyo` convention).
export function notifySendArgv(
  summary: string,
  body?: string,
  opts: { urgency?: "low" | "normal" | "critical"; app?: string } = {},
): string[] {
  const argv = [
    "notify-send",
    "-u",
    opts.urgency ?? "low",
    "-a",
    opts.app ?? "marchyo",
    summary,
  ];
  if (body !== undefined) argv.push(body);
  return argv;
}

export function awwwImgArgv(image: string): string[] {
  return ["awww", "img", image, "--transition-type", "none"];
}
