import { homedir } from "node:os";
import { join } from "node:path";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  err,
  info,
  notifySendArgv,
  ok,
  runArgv,
  usageError,
} from "@marchyo/core";

// Stateless capture actions (F3.2): screenshot / record / ocr / color.
// Unlike toggles these report failure — a missing tool is an error (exit 1),
// not a silent no-op, since the user asked for an artifact.

const TARGETS = ["area", "active", "output", "screen"] as const;
type Target = (typeof TARGETS)[number];

const AUDIO = ["none", "desktop", "mic"] as const;
type Audio = (typeof AUDIO)[number];

function require(rt: Runtime, tool: string): boolean {
  if (commandAvailable(tool)) return true;
  err(rt, `${tool} not found in PATH (is marchyo.desktop enabled?)`);
  return false;
}

function timestamp(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`;
}

function screenshotsDir(): string {
  return (
    process.env.XDG_SCREENSHOTS_DIR ??
    join(homedir(), "Pictures", "Screenshots")
  );
}

export type ScreenshotOpts = { target?: string; edit?: boolean };

export async function runCaptureScreenshot(
  rt: Runtime,
  opts: ScreenshotOpts,
): Promise<number> {
  const target = (opts.target ?? "area") as Target;
  if (!TARGETS.includes(target)) {
    return usageError(
      rt,
      `invalid target: "${opts.target}"`,
      `marchyo capture screenshot --target <${TARGETS.join("|")}>`,
    );
  }
  if (!require(rt, "grimblast")) return 1;

  if (opts.edit) {
    // The annotation flow pipes the frozen grab into satty (same pipeline
    // the old inline bind used).
    if (!require(rt, "satty")) return 1;
    const out = join(screenshotsDir(), `${timestamp()}_annotated.png`);
    return runArgv([
      "sh",
      "-c",
      `grimblast --freeze save ${target} - | satty --filename - --output-filename '${out}'`,
    ]);
  }
  return runArgv([
    "grimblast",
    "--notify",
    ...(target === "area" ? ["--freeze"] : []),
    "copysave",
    target,
  ]);
}

export type RecordOpts = { audio?: string };

// Absorbed from marchyo-screenrecord-toggle: gpu-screen-recorder on a
// slurp-selected region; a second invocation stops and finalizes the mp4.
export async function runCaptureRecord(
  rt: Runtime,
  opts: RecordOpts,
): Promise<number> {
  const audio = (opts.audio ?? "none") as Audio;
  if (!AUDIO.includes(audio)) {
    return usageError(
      rt,
      `invalid audio source: "${opts.audio}"`,
      `marchyo capture record --audio <${AUDIO.join("|")}>`,
    );
  }

  // Match the full command line: the kernel truncates comm to 15 chars
  // ("gpu-screen-reco"), so pgrep -x on the full name never matches.
  const running = await captureArgv(["pgrep", "-f", "gpu-screen-recorder"]);
  const recdir = join(homedir(), "Videos", "Recordings");
  if (running.code === 0) {
    await runArgv(["pkill", "-INT", "-f", "gpu-screen-recorder"]);
    await runArgv(notifySendArgv("Screen recording", `Saved to ${recdir}`)).catch(
      () => 0,
    );
    ok(rt, `recording saved to ${recdir}`);
    return 0;
  }

  if (!require(rt, "gpu-screen-recorder") || !require(rt, "slurp")) return 1;
  const region = await captureArgv(["slurp", "-f", "%wx%h+%x+%y"]);
  if (region.code !== 0 || region.stdout.trim() === "") {
    info(rt, "selection cancelled");
    return 0;
  }
  await runArgv(["mkdir", "-p", recdir]);
  const out = join(recdir, `${timestamp()}.mp4`);
  const argv = [
    "gpu-screen-recorder",
    "-w",
    "region",
    "-region",
    region.stdout.trim(),
    "-f",
    "60",
    ...(audio === "desktop"
      ? ["-a", "default_output"]
      : audio === "mic"
        ? ["-a", "default_input"]
        : []),
    "-o",
    out,
  ];
  try {
    const proc = Bun.spawn(argv, {
      stdout: "ignore",
      stderr: "ignore",
      stdin: "ignore",
    });
    proc.unref();
  } catch {
    err(rt, "failed to start gpu-screen-recorder");
    return 1;
  }
  await runArgv(notifySendArgv("Screen recording", "Recording started")).catch(
    () => 0,
  );
  ok(rt, `recording to ${out} (run again to stop)`);
  return 0;
}

export async function runCaptureOcr(rt: Runtime): Promise<number> {
  for (const tool of ["grimblast", "tesseract", "wl-copy"]) {
    if (!require(rt, tool)) return 1;
  }
  const code = await runArgv([
    "sh",
    "-c",
    "grimblast --freeze save area - | tesseract - - | wl-copy",
  ]);
  if (code === 0) ok(rt, "text copied to clipboard");
  return code;
}

export async function runCaptureColor(rt: Runtime): Promise<number> {
  if (!require(rt, "hyprpicker")) return 1;
  return runArgv(["hyprpicker", "-a"]);
}
