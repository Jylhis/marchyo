import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { appendFile, mkdir, writeFile } from "node:fs/promises";
import { basename, dirname, extname, join } from "node:path";
import { homedir } from "node:os";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  data,
  err,
  hint,
  info,
  notifySendArgv,
  ok,
  runArgv,
  usageError,
} from "@marchyo/core";
import {
  type DeviceInfo,
  type Discover,
  type Fetch,
  type Peer,
  type SendFile,
  LocalSendError,
  discoverPeers,
  expandPaths,
  matchPeer,
  parseAddress,
  registerWith,
  selfInfo,
  sendFiles,
  textEntry,
} from "@marchyo/core/localsend";
import { gumChoose, gumFile, gumInput } from "./menu.ts";

// Utilities: reminders (transient systemd user timers), quick-info
// notifications, media transcode, and LocalSend share. gum presentation stays; logic
// lives here.

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

const FFMPEG_ARGS: Record<string, string[]> = {
  mp4: ["-c:v", "libx264", "-preset", "fast", "-crf", "23", "-c:a", "aac"],
  webm: ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"],
  gif: ["-vf", "fps=12,scale=640:-1:flags=lanczos"],
};

export type TranscodeOpts = { ascii?: boolean; imageAscii?: boolean; to?: string };

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

  if (opts.imageAscii) {
    // Render an image as ASCII/ANSI art to stdout with chafa. No output file.
    if (!commandAvailable("chafa")) {
      err(rt, "chafa not found in PATH");
      return 1;
    }
    return runArgv(["chafa", src]);
  }

  let target = opts.to ?? null;
  if (target === null) {
    const choices = [
      "mp4",
      "webm",
      "gif",
      ...(commandAvailable("tte") ? ["ascii (tte)"] : []),
      ...(commandAvailable("chafa") ? ["ascii-art (chafa)"] : []),
    ];
    target = await gumChoose("Transcode to", choices);
  }
  if (target === null) return 0;
  if (target === "ascii (tte)") return runTranscode(rt, src, { ascii: true });
  if (target === "ascii-art (chafa)") return runTranscode(rt, src, { imageAscii: true });
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

export type ShareOpts = { to?: string; clipboard?: boolean; pin?: string };

// Every effect of `marchyo share` that touches the network, the desktop or a
// prompt, injectable so tests run offline.
export type ShareDeps = {
  discover: Discover;
  register: (ip: string, port: number, self: DeviceInfo) => Promise<Peer | null>;
  fetch: Fetch;
  interactive: boolean;
  choose: (header: string, options: string[]) => Promise<string | null>;
  pickPath: (directory: boolean) => Promise<string | null>;
  readClipboard: () => Promise<string | null>;
  notify: (urgency: "low" | "critical", summary: string, body: string) => Promise<void>;
  // Opens the LocalSend app; false when it is not installed.
  openLocalSend: () => boolean;
};

const DISCOVERY_MS = 2000;

export function defaultShareDeps(rt: Runtime): ShareDeps {
  return {
    discover: discoverPeers,
    register: (ip, port, self) => registerWith(ip, port, self),
    fetch,
    interactive: !rt.noInput && process.stdin.isTTY === true && commandAvailable("gum"),
    choose: gumChoose,
    pickPath: (directory) => gumFile(homedir(), directory),
    readClipboard: async () => {
      const r = await captureArgv(["wl-paste", "--no-newline"]);
      return r.code === 0 ? r.stdout : null;
    },
    notify,
    openLocalSend: () => {
      if (!commandAvailable("localsend_app")) return false;
      try {
        Bun.spawn(["localsend_app"], { stdout: "ignore", stderr: "ignore", stdin: "ignore" }).unref();
        return true;
      } catch {
        return false;
      }
    },
  };
}

function peerLabel(p: Peer): string {
  return `${p.alias} (${p.ip})`;
}

async function shareToClipboard(rt: Runtime, path: string): Promise<number> {
  if (!commandAvailable("wl-copy")) {
    err(rt, "wl-copy not found in PATH");
    return 1;
  }
  // A file's contents, or a folder's path.
  const isDir = statSync(path).isDirectory();
  const proc = Bun.spawn(["wl-copy"], {
    stdin: isDir ? new Blob([path]) : Bun.file(path),
    stdout: "ignore",
    stderr: "inherit",
  });
  const code = await proc.exited;
  if (code === 0) ok(rt, isDir ? `copied path ${path}` : `copied contents of ${basename(path)}`);
  return code;
}

async function resolvePeer(
  rt: Runtime,
  self: DeviceInfo,
  to: string | undefined,
  deps: ShareDeps,
): Promise<Peer | null> {
  if (to !== undefined) {
    const addr = parseAddress(to);
    if (addr) {
      const p = await deps.register(addr.ip, addr.port, self);
      if (!p) err(rt, `no LocalSend device answers at ${to}`);
      return p;
    }
  }
  const peers = await deps.discover({ self, timeoutMs: DISCOVERY_MS });
  if (to !== undefined) {
    const p = matchPeer(peers, to);
    if (!p) {
      err(rt, `no LocalSend device named "${to}" found`);
      if (peers.length > 0) hint(rt, `Found: ${peers.map(peerLabel).join(", ")}`);
    }
    return p;
  }
  if (peers.length === 0) {
    err(rt, "no LocalSend devices found on the local network");
    hint(rt, "Open LocalSend on the receiving device, or pass --to <ip>");
    if (
      deps.interactive &&
      (await deps.choose("No LocalSend devices found", ["Open LocalSend", "Cancel"])) ===
        "Open LocalSend" &&
      !deps.openLocalSend()
    ) {
      err(rt, "localsend_app not found in PATH");
    }
    return null;
  }
  if (peers.length === 1) return peers[0]!;
  if (!deps.interactive) {
    err(rt, `${peers.length} LocalSend devices found; pick one with --to`);
    hint(rt, `Found: ${peers.map(peerLabel).join(", ")}`);
    return null;
  }
  const choice = await deps.choose("Send to", peers.map(peerLabel));
  return peers.find((p) => peerLabel(p) === choice) ?? null;
}

// Sends files, folders or clipboard text to a nearby LocalSend device
// (protocol v2, see @marchyo/core/localsend); --clipboard copies instead.
export async function runShare(
  rt: Runtime,
  paths: string[],
  opts: ShareOpts = {},
  deps: ShareDeps = defaultShareDeps(rt),
): Promise<number> {
  for (const p of paths) {
    if (!existsSync(p)) {
      err(rt, `no such file: ${p}`);
      return 1;
    }
  }

  if (opts.clipboard) {
    if (paths.length !== 1) {
      return usageError(rt, "--clipboard takes exactly one path", "marchyo share --clipboard <path>");
    }
    return shareToClipboard(rt, paths[0]!);
  }

  let files: SendFile[];
  if (paths.length > 0) {
    files = await expandPaths(paths);
  } else {
    if (!deps.interactive) {
      return usageError(rt, "nothing to share", "marchyo share <path...> [--to <alias|ip>]");
    }
    const choice = await deps.choose("Share", ["File", "Folder", "Clipboard"]);
    if (choice === "File" || choice === "Folder") {
      const picked = await deps.pickPath(choice === "Folder");
      if (picked === null) return 0;
      files = await expandPaths([picked]);
    } else if (choice === "Clipboard") {
      const text = await deps.readClipboard();
      if (text === null || text === "") {
        err(rt, "clipboard is empty (or wl-paste is missing)");
        return 1;
      }
      files = [textEntry(text)];
    } else {
      return 0;
    }
  }
  if (files.length === 0) {
    err(rt, "nothing to send: the selection contains no regular files");
    return 1;
  }

  const self = selfInfo();
  const peer = await resolvePeer(rt, self, opts.to, deps);
  if (!peer) return 1;

  info(rt, `waiting for ${peer.alias} to accept ${files.length} file(s)`);
  try {
    const result = await sendFiles(peer, files, {
      self,
      pin: opts.pin,
      fetch: deps.fetch,
      onAccepted: () => deps.notify("low", "Share", `${peer.alias} accepted`),
    });
    const summary =
      result.status === "finished"
        ? `delivered to ${peer.alias}`
        : `sent ${result.sent} file(s) to ${peer.alias}` +
          (result.skipped > 0 ? ` (${result.skipped} declined)` : "");
    await deps.notify("low", "Share", summary);
    if (rt.format === "json") {
      data(
        rt,
        { share: { peer: { alias: peer.alias, ip: peer.ip }, ...result } },
        () => summary,
      );
    } else {
      ok(rt, summary);
    }
    return 0;
  } catch (e) {
    const msg = (e as Error).message;
    const kind = e instanceof LocalSendError ? e.kind : "network";
    await deps.notify(
      "critical",
      "Share",
      kind === "rejected" ? `${peer.alias} declined the transfer` : msg,
    );
    err(rt, msg);
    if (kind === "pin") hint(rt, "Try: marchyo share --pin <pin> ...");
    return 1;
  }
}
