import { basename } from "node:path";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  data,
  err,
  hyprctlDispatchArgv,
  hyprlandAvailable,
  notifySendArgv,
  runArgv,
  shellInstalled,
  shellIpc,
  usageError,
  warn,
  tr,
} from "@marchyo/core";
import { reportShellIpcError } from "./shell.ts";

// Power/session commands. The gum menu presentation lives in
// commands/menu.ts and dispatches here.

function detach(argv: string[]): boolean {
  try {
    const proc = Bun.spawn(argv, {
      stdout: "ignore",
      stderr: "ignore",
      stdin: "ignore",
    });
    proc.unref();
    return true;
  } catch {
    return false;
  }
}

// Lock with the marchyo shell's lock screen when the shell is installed;
// hyprlock covers a shell that is not running and hosts without the shell.
export async function runLock(rt: Runtime): Promise<number> {
  if (shellInstalled()) {
    try {
      await shellIpc("lock");
      return 0;
    } catch (e) {
      if (!commandAvailable("hyprlock")) return reportShellIpcError(rt, e);
    }
  }
  // Detached so the invoking terminal/menu window can close without
  // killing the locker.
  if (!commandAvailable("hyprlock")) {
    err(rt, tr("power.hyprlockNotFoundInPath"));
    return 1;
  }
  return detach(["hyprlock"]) ? 0 : 1;
}

// Session exits (logout, reboot, shutdown) close every window first, so apps
// save their state and the exit does not wait on systemd's stop timeouts.
// Called from a Hyprland session, the verb hands itself to a transient
// `systemd-run --user` unit (it survives the terminal or menu that asked) with
// SESSION_EXIT_ENV set; in the unit it closes the windows, waits up to
// CLOSE_WAIT_MS for their processes, then exits, and reports a failed exit.
export type SessionExit = "logout" | "reboot" | "shutdown";
export const SESSION_EXIT_ENV = "MARCHYO_SESSION_EXIT";
export const CLOSE_WAIT_MS = 2000;

// The running CLI's own argv: the compiled binary, or bun plus the script.
function selfArgv(): string[] {
  const exe = process.execPath;
  if (basename(exe) === "bun" && process.argv[1]) return [exe, process.argv[1]];
  return [exe];
}

export function sessionExitUnitArgv(action: SessionExit, self: string[]): string[] {
  const verb = [...self, action];
  const command =
    action === "shutdown"
      ? [
          "systemd-inhibit",
          "--what=sleep:idle:handle-lid-switch",
          "--who=marchyo",
          "--why=Shutdown in progress",
          "--mode=block",
          ...verb,
        ]
      : verb;
  return [
    "systemd-run",
    "--user",
    "--collect",
    "--quiet",
    "--property=Type=exec",
    "--property=RuntimeMaxSec=30s",
    "--setenv=PATH",
    "--setenv=HYPRLAND_INSTANCE_SIGNATURE",
    "--setenv=WAYLAND_DISPLAY",
    `--setenv=${SESSION_EXIT_ENV}=1`,
    "--",
    ...command,
  ];
}

// Window addresses and owning pids from `hyprctl clients -j`.
export function parseClients(json: string): { addresses: string[]; pids: number[] } {
  let list: unknown;
  try {
    list = JSON.parse(json);
  } catch {
    return { addresses: [], pids: [] };
  }
  if (!Array.isArray(list)) return { addresses: [], pids: [] };
  const addresses: string[] = [];
  const pids = new Set<number>();
  for (const c of list as Array<{ address?: unknown; pid?: unknown }>) {
    if (typeof c.address === "string" && /^0x[0-9a-fA-F]+$/.test(c.address)) {
      addresses.push(c.address);
    }
    if (typeof c.pid === "number" && Number.isInteger(c.pid) && c.pid > 0) pids.add(c.pid);
  }
  return { addresses, pids: [...pids].filter((p) => p !== process.pid) };
}

export const closeWindowDispatch = (address: string): string =>
  `hl.dsp.window.close({ window = "address:${address}" })`;

function alive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function closeAllWindows(): Promise<void> {
  const r = await captureArgv(["hyprctl", "clients", "-j"]);
  if (r.code !== 0) return;
  const { addresses, pids } = parseClients(r.stdout);
  await Promise.all(
    addresses.map((a) => captureArgv(hyprctlDispatchArgv(closeWindowDispatch(a)))),
  );
  const deadline = Date.now() + CLOSE_WAIT_MS;
  let waiting = pids.filter(alive);
  while (waiting.length > 0 && Date.now() < deadline) {
    await Bun.sleep(50);
    waiting = waiting.filter(alive);
  }
}

// worker: inside the unit, close the windows, then exit. handoff: start the
// unit. direct: exit without closing windows (no session, no systemd-run, or
// a failed handoff), because closing them here would kill the terminal that
// runs this command.
export type SessionExitPlan = "worker" | "handoff" | "direct";

export function sessionExitPlan(
  env: NodeJS.ProcessEnv,
  session: boolean,
  haveSystemdRun: boolean,
): SessionExitPlan {
  if (env[SESSION_EXIT_ENV] === "1") return session ? "worker" : "direct";
  return session && haveSystemdRun ? "handoff" : "direct";
}

const EXIT_FAILED: Record<SessionExit, string> = {
  logout: "Logout failed",
  reboot: "Reboot failed",
  shutdown: "Shutdown failed",
};

async function sessionExit(
  rt: Runtime,
  action: SessionExit,
  finish: () => Promise<number>,
): Promise<number> {
  const session = hyprlandAvailable() && commandAvailable("hyprctl");
  const plan = sessionExitPlan(process.env, session, commandAvailable("systemd-run"));
  if (plan === "handoff") {
    const r = await captureArgv(sessionExitUnitArgv(action, selfArgv()));
    if (r.code === 0) return 0;
    warn(rt, tr("power.couldNotStartTheUnit", action, r.code));
    return finish();
  }
  if (plan === "direct") return finish();
  await closeAllWindows();
  const code = await finish();
  if (code !== 0) {
    err(rt, tr("power.failedExit", action, code));
    await captureArgv(
      notifySendArgv(EXIT_FAILED[action], `exit ${code}; try again`, { urgency: "critical" }),
    );
  }
  return code;
}

// End the session cleanly: uwsm-managed sessions stop through uwsm (greetd
// then shows the greeter again); otherwise exit the compositor; last resort
// terminate the whole login session.
async function endSession(rt: Runtime): Promise<number> {
  if (commandAvailable("uwsm")) {
    const active = await captureArgv(["uwsm", "check", "is-active"]);
    if (active.code === 0) return runArgv(["uwsm", "stop"]);
  }
  if (commandAvailable("hyprctl")) {
    return runArgv(hyprctlDispatchArgv("hl.dsp.exit()"));
  }
  const user = process.env.USER;
  if (!user) {
    err(rt, tr("power.cannotDetermineSessionUser"));
    return 1;
  }
  return runArgv(["loginctl", "terminate-user", user]);
}

export const runLogout = (rt: Runtime): Promise<number> =>
  sessionExit(rt, "logout", () => endSession(rt));

export const runSuspend = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "suspend"]);
export const runHibernate = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "hibernate"]);
export const runReboot = (rt: Runtime): Promise<number> =>
  sessionExit(rt, "reboot", () => runArgv(["systemctl", "reboot", "--no-wall"]));
export const runRebootFirmware = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "reboot", "--firmware-setup"]);
export const runShutdown = (rt: Runtime): Promise<number> =>
  sessionExit(rt, "shutdown", () => runArgv(["systemctl", "poweroff", "--no-wall"]));

// Lock first so the machine always wakes up locked.
export async function runLockSuspend(rt: Runtime): Promise<number> {
  const code = await runLock(rt);
  return code === 0 ? runSuspend(rt) : code;
}

const PROFILES = ["power-saver", "balanced", "performance"] as const;

export async function runPowerprofile(
  rt: Runtime,
  action: string,
  profile?: string,
): Promise<number> {
  if (!commandAvailable("powerprofilesctl")) {
    err(rt, tr("power.powerprofilesctlNotFoundPowerProfiles"));
    return 1;
  }
  switch (action) {
    case "get": {
      const r = await captureArgv(["powerprofilesctl", "get"]);
      if (r.code !== 0) {
        err(rt, tr("power.powerProfilesDaemonUnavailable"));
        return 1;
      }
      const current = r.stdout.trim();
      data(rt, { powerprofile: current }, () => current);
      return 0;
    }
    case "list":
      return runArgv(["powerprofilesctl", "list"]);
    case "set": {
      if (!profile || !PROFILES.includes(profile as (typeof PROFILES)[number])) {
        return usageError(
          rt,
          tr("power.invalidProfile", profile ?? ""),
          `marchyo powerprofile set <${PROFILES.join("|")}>`,
        );
      }
      return runArgv(["powerprofilesctl", "set", profile]);
    }
    default:
      return usageError(
        rt,
        tr("dictation.unknownAction", action),
        "marchyo powerprofile <get|list|set>",
      );
  }
}

// Cycle power-saver → balanced → performance → power-saver, snapping back
// to power-saver on unsupported profiles (menu Setup entry behavior).
export async function cyclePowerProfile(): Promise<string | null> {
  const cur = await captureArgv(["powerprofilesctl", "get"]);
  if (cur.code !== 0) return null;
  const current = cur.stdout.trim();
  const next =
    current === "power-saver"
      ? "balanced"
      : current === "balanced"
        ? "performance"
        : "power-saver";
  const set = await captureArgv(["powerprofilesctl", "set", next]);
  if (set.code !== 0) {
    await captureArgv(["powerprofilesctl", "set", "power-saver"]);
    return "power-saver";
  }
  return next;
}
