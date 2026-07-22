import { existsSync, readdirSync, readFileSync } from "node:fs";
import { appendFile, mkdir, writeFile } from "node:fs/promises";
import { basename, dirname, extname, join } from "node:path";
import { homedir } from "node:os";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  err,
  notifySendArgv,
  ok,
  runArgv,
  usageError,
} from "@marchyo/core";
import { gumChoose, gumFile, gumInput } from "./menu.ts";

// Utilities (F3.2): reminders (transient systemd user timers), quick-info
// notifications, media transcode, and share — absorbed from the seven
// utilities.nix scripts. gum presentation stays; logic lives here.

function stateDir(): string {
  const xdg = process.env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo");
}

async function notify(
  urgency: "low" | "critical",
  summary: string,
  body: string,
): Promise<void> {
  await runArgv(notifySendArgv(summary, body, { urgency })).catch(() => 0);
}

// -- reminders -------------------------------------------------------------

export async function runReminderSet(
  rt: Runtime,
  message?: string,
  delayArg?: string,
): Promise<number> {
  const msg = message ?? (await gumInput("Reminder: ", "Remind me to..."));
  if (msg === null || msg === "") return 0;
  const delay =
    delayArg ?? (await gumInput("In: ", "10m, 2h, 1h30m...", "10m"));
  if (delay === null || delay === "") return 0;

  // notify-send resolves inside the transient unit's own PATH on NixOS
  // (systemd user units get the profile PATH). Nanoseconds keep
  // same-second reminders from colliding on the unit name.
  const unit = `marchyo-reminder-${Date.now()}${String(process.hrtime()[1]).padStart(9, "0")}`;
  const code = await runArgv([
    "systemd-run",
    "--user",
    `--on-active=${delay}`,
    `--unit=${unit}`,
    `--description=marchyo reminder: ${msg}`,
    "notify-send",
    "-u",
    "critical",
    "Reminder",
    msg,
  ]);
  if (code !== 0) {
    await notify(
      "critical",
      "Reminder",
      `Could not schedule reminder - is "${delay}" a valid delay?`,
    );
    err(rt, `systemd-run rejected the reminder (delay "${delay}"?)`);
    return 1;
  }

  await mkdir(stateDir(), { recursive: true });
  const now = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  const stamp = `${now.getFullYear()}-${p(now.getMonth() + 1)}-${p(now.getDate())} ${p(now.getHours())}:${p(now.getMinutes())}`;
  await appendFile(join(stateDir(), "reminders"), `${stamp} | ${delay} | ${msg}\n`);
  await notify("low", "Reminder set", `In ${delay}: ${msg}`);
  ok(rt, `reminder in ${delay}: ${msg}`);
  return 0;
}

export async function runReminderShow(rt: Runtime): Promise<number> {
  const timers = await captureArgv([
    "systemctl",
    "--user",
    "list-timers",
    "--all",
    "marchyo-reminder-*",
    "--no-pager",
  ]);
  const statefile = join(stateDir(), "reminders");
  let log = "(empty)";
  try {
    const raw = readFileSync(statefile, "utf8");
    if (raw.trim() !== "") log = raw.trimEnd();
  } catch {
    // no log yet
  }
  const report = `Pending reminders:\n${timers.stdout.trimEnd()}\n\nReminder log:\n${log}`;
  if (commandAvailable("gum") && process.stdout.isTTY) {
    try {
      const proc = Bun.spawn(["gum", "pager"], {
        stdin: "pipe",
        stdout: "inherit",
        stderr: "inherit",
      });
      proc.stdin.write(report + "\n");
      await proc.stdin.end();
      await proc.exited;
      return 0;
    } catch {
      // fall through to plain output
    }
  }
  process.stdout.write(report + "\n");
  return 0;
}

export async function runReminderClear(rt: Runtime): Promise<number> {
  // The wildcard covers both the transient .timer units and any .service
  // units already spawned by an elapsed timer.
  await captureArgv(["systemctl", "--user", "stop", "marchyo-reminder-*"]);
  await mkdir(stateDir(), { recursive: true });
  await writeFile(join(stateDir(), "reminders"), "");
  await notify("low", "Reminders", "Cleared pending reminders");
  ok(rt, "reminders cleared");
  return 0;
}

// -- quick info ------------------------------------------------------------

export async function runInfo(rt: Runtime, what: string): Promise<number> {
  switch (what) {
    case "datetime": {
      const now = new Date();
      const date = now.toLocaleDateString(undefined, {
        weekday: "long",
        day: "numeric",
        month: "long",
      });
      const time = now.toLocaleTimeString(undefined, {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
      await notify("low", date, time);
      return 0;
    }
    case "battery": {
      let found = false;
      let bats: string[] = [];
      try {
        bats = readdirSync("/sys/class/power_supply").filter((d) =>
          d.startsWith("BAT"),
        );
      } catch {
        bats = [];
      }
      for (const bat of bats) {
        const base = join("/sys/class/power_supply", bat);
        let capacity: string;
        let status: string;
        try {
          capacity = readFileSync(join(base, "capacity"), "utf8").trim();
          status = readFileSync(join(base, "status"), "utf8").trim();
        } catch {
          continue;
        }
        found = true;
        const urgency =
          status === "Discharging" && Number(capacity) <= 20
            ? "critical"
            : "low";
        await notify(urgency, `Battery ${capacity}%`, `${bat}: ${status}`);
      }
      if (!found) await notify("low", "Battery", "No battery detected");
      return 0;
    }
    default:
      return usageError(
        rt,
        `unknown info: "${what}"`,
        "marchyo info <datetime|battery>",
      );
  }
}

// -- transcode -------------------------------------------------------------

const FFMPEG_ARGS: Record<string, string[]> = {
  mp4: ["-c:v", "libx264", "-preset", "fast", "-crf", "23", "-c:a", "aac"],
  webm: ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"],
  gif: ["-vf", "fps=12,scale=640:-1:flags=lanczos"],
};

export type TranscodeOpts = { ascii?: boolean; to?: string };

export async function runTranscode(
  rt: Runtime,
  file: string | undefined,
  opts: TranscodeOpts,
): Promise<number> {
  const src = file ?? (await gumFile(homedir()));
  if (src === null || src === undefined) return 0;
  if (!existsSync(src)) {
    err(rt, `not a file: ${src}`);
    return 1;
  }

  if (opts.ascii) {
    // Text-mode "transcode": animate the file's text with tte. No output.
    if (!commandAvailable("tte")) {
      err(rt, "tte (terminaltexteffects) not found in PATH");
      return 1;
    }
    return runArgv(["sh", "-c", `tte beams < '${src.replace(/'/g, `'\\''`)}'`]);
  }

  let target = opts.to ?? null;
  if (target === null) {
    const choices = [
      "mp4",
      "webm",
      "gif",
      ...(commandAvailable("tte") ? ["ascii (tte)"] : []),
    ];
    target = await gumChoose("Transcode to", choices);
  }
  if (target === null) return 0;
  if (target === "ascii (tte)") return runTranscode(rt, src, { ascii: true });
  const args = FFMPEG_ARGS[target];
  if (!args) {
    return usageError(
      rt,
      `invalid target format: "${target}"`,
      "marchyo transcode <file> --to <mp4|webm|gif> (or --ascii)",
    );
  }
  if (!commandAvailable("ffmpeg")) {
    err(rt, "ffmpeg not found in PATH");
    return 1;
  }

  const dir = dirname(src);
  const stem = basename(src, extname(src));
  // Transcode lands next to the source; dodge in-place overwrites when the
  // source already has the target extension.
  let out = join(dir, `${stem}.${target}`);
  if (out === src) out = join(dir, `${stem}.transcoded.${target}`);

  const code = await runArgv(["ffmpeg", "-y", "-i", src, ...args, out]);
  if (code !== 0) {
    await notify("critical", "Transcode", `ffmpeg failed transcoding ${basename(src)}`);
    return 1;
  }
  await notify("low", "Transcode", `Saved ${basename(out)}`);
  ok(rt, `saved ${out}`);
  return 0;
}

// -- share -----------------------------------------------------------------

// Copies the chosen content/path to the clipboard; an actual upload target
// is deferred (follow-up decision per OMARCHY_PARITY.md).
export async function runShare(
  rt: Runtime,
  file?: string,
): Promise<number> {
  if (!commandAvailable("wl-copy")) {
    err(rt, "wl-copy not found in PATH");
    return 1;
  }
  if (file !== undefined) {
    if (!existsSync(file)) {
      err(rt, `no such file: ${file}`);
      return 1;
    }
    const code = await runArgv(["sh", "-c", `wl-copy < '${file.replace(/'/g, `'\\''`)}'`]);
    if (code === 0) ok(rt, `copied contents of ${basename(file)}`);
    return code;
  }

  const choice = await gumChoose("Share", ["Clipboard", "File", "Folder"]);
  switch (choice) {
    case "Clipboard":
      await notify("low", "Share", "Clipboard content ready to paste");
      return 0;
    case "File": {
      const f = await gumFile(homedir());
      if (f === null) return 0;
      const code = await runArgv(["sh", "-c", `wl-copy < '${f.replace(/'/g, `'\\''`)}'`]);
      if (code === 0)
        await notify("low", "Share", `Copied contents of ${basename(f)}`);
      return code;
    }
    case "Folder": {
      const d = await gumFile(homedir(), true);
      if (d === null) return 0;
      const code = await runArgv(["sh", "-c", `printf '%s' '${d.replace(/'/g, `'\\''`)}' | wl-copy`]);
      if (code === 0) await notify("low", "Share", `Copied path ${d}`);
      return code;
    }
    default:
      return 0;
  }
}
