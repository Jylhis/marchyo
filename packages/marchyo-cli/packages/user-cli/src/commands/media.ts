import {
  type Runtime,
  captureArgv,
  commandAvailable,
  err,
  shellInstalled,
  shellIpc,
  usageError,
} from "@marchyo/core";

// Volume and brightness keys. Three backends, picked per call:
//  - the marchyo shell installed: silent wpctl / brightnessctl. The shell OSD
//    reacts to Pipewire natively; brightness gets an explicit `osdShow` poke
//    because sysfs writes signal POLLPRI, which the shell's inotify watcher
//    does not see on most hosts.
//  - SwayOSD (no shell): swayosd-client does the change and shows the OSD.
//  - neither: silent wpctl / brightnessctl.

export type MediaBackend = "shell" | "swayosd" | "plain";

export function pickMediaBackend(
  shell: boolean = shellInstalled(),
  swayosd: boolean = commandAvailable("swayosd-client"),
): MediaBackend {
  if (shell) return "shell";
  return swayosd ? "swayosd" : "plain";
}

export const VOLUME_ACTIONS = ["up", "down", "mute"] as const;
export type VolumeAction = (typeof VOLUME_ACTIONS)[number];
export const BRIGHTNESS_ACTIONS = ["up", "down"] as const;
export type BrightnessAction = (typeof BRIGHTNESS_ACTIONS)[number];

export function volumeArgv(
  backend: MediaBackend,
  action: VolumeAction,
  mic: boolean,
): string[] {
  if (backend === "swayosd") {
    const op = { up: "raise", down: "lower", mute: "mute-toggle" }[action];
    return ["swayosd-client", mic ? "--input-volume" : "--output-volume", op];
  }
  const node = mic ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@";
  switch (action) {
    case "up":
      return ["wpctl", "set-volume", "-l", "1", node, "5%+"];
    case "down":
      return ["wpctl", "set-volume", node, "5%-"];
    case "mute":
      return ["wpctl", "set-mute", node, "toggle"];
  }
}

export function brightnessArgv(
  backend: MediaBackend,
  action: BrightnessAction,
): string[] {
  if (backend === "swayosd") {
    return ["swayosd-client", "--brightness", action === "up" ? "raise" : "lower"];
  }
  return ["brightnessctl", "-e4", "-n2", "set", action === "up" ? "5%+" : "5%-"];
}

// Current backlight level in percent, or null when brightnessctl cannot
// report a usable max (no backlight, or max 0).
export function brightnessPercent(current: string, max: string): number | null {
  const c = Number.parseInt(current.trim(), 10);
  const m = Number.parseInt(max.trim(), 10);
  if (!Number.isFinite(c) || !Number.isFinite(m) || m <= 0) return null;
  return Math.floor((c * 100) / m);
}

async function exec(rt: Runtime, argv: string[]): Promise<number> {
  const tool = argv[0] ?? "";
  if (!commandAvailable(tool)) {
    err(rt, `${tool} not found in PATH`);
    return 1;
  }
  const r = await captureArgv(argv);
  if (r.code !== 0) err(rt, `${tool} exited ${r.code}`);
  return r.code === 0 ? 0 : 1;
}

export async function runVolume(
  rt: Runtime,
  action: string,
  opts: { mic?: boolean },
): Promise<number> {
  if (!(VOLUME_ACTIONS as readonly string[]).includes(action)) {
    return usageError(
      rt,
      `invalid volume action: "${action}"`,
      "marchyo volume up|down|mute [--mic]",
    );
  }
  const backend = pickMediaBackend();
  return exec(rt, volumeArgv(backend, action as VolumeAction, opts.mic === true));
}

export async function runBrightness(
  rt: Runtime,
  action: string,
): Promise<number> {
  if (!(BRIGHTNESS_ACTIONS as readonly string[]).includes(action)) {
    return usageError(
      rt,
      `invalid brightness action: "${action}"`,
      "marchyo brightness up|down",
    );
  }
  const backend = pickMediaBackend();
  const code = await exec(rt, brightnessArgv(backend, action as BrightnessAction));
  if (code !== 0 || backend !== "shell") return code;

  // Best effort: the change already happened, so a missing backlight or a
  // stopped shell never fails the key press.
  const [cur, max] = await Promise.all([
    captureArgv(["brightnessctl", "get"]),
    captureArgv(["brightnessctl", "max"]),
  ]);
  const pct = brightnessPercent(cur.stdout, max.stdout);
  if (pct !== null) {
    await shellIpc("osdShow", "BRT", String(pct), "true").catch(() => "");
  }
  return 0;
}
