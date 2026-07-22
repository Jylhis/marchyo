import {
  type Runtime,
  captureArgv,
  commandAvailable,
  data,
  err,
  runArgv,
  usageError,
} from "@marchyo/core";

// Power/session commands (F3.2), absorbed from marchyo-power-menu's action
// arms. The gum menu presentation lives in commands/menu.ts and dispatches
// here.

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

export async function runLock(rt: Runtime): Promise<number> {
  // Detached so the invoking terminal/menu window can close without
  // killing the locker.
  if (!commandAvailable("hyprlock")) {
    err(rt, "hyprlock not found in PATH");
    return 1;
  }
  return detach(["hyprlock"]) ? 0 : 1;
}

// End the session cleanly: uwsm-managed sessions stop through uwsm (greetd
// then shows the greeter again); otherwise exit the compositor; last resort
// terminate the whole login session.
export async function runLogout(rt: Runtime): Promise<number> {
  if (commandAvailable("uwsm")) {
    const active = await captureArgv(["uwsm", "check", "is-active"]);
    if (active.code === 0) return runArgv(["uwsm", "stop"]);
  }
  if (commandAvailable("hyprctl")) {
    return runArgv(["hyprctl", "dispatch", "exit"]);
  }
  const user = process.env.USER;
  if (!user) {
    err(rt, "cannot determine session user");
    return 1;
  }
  return runArgv(["loginctl", "terminate-user", user]);
}

export const runSuspend = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "suspend"]);
export const runHibernate = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "hibernate"]);
export const runReboot = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "reboot"]);
export const runShutdown = (_rt: Runtime): Promise<number> =>
  runArgv(["systemctl", "poweroff"]);

const PROFILES = ["power-saver", "balanced", "performance"] as const;

export async function runPowerprofile(
  rt: Runtime,
  action: string,
  profile?: string,
): Promise<number> {
  if (!commandAvailable("powerprofilesctl")) {
    err(rt, "powerprofilesctl not found (power-profiles-daemon disabled or replaced, e.g. by TLP)");
    return 1;
  }
  switch (action) {
    case "get": {
      const r = await captureArgv(["powerprofilesctl", "get"]);
      if (r.code !== 0) {
        err(rt, "power-profiles-daemon unavailable");
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
          `invalid profile: "${profile ?? ""}"`,
          `marchyo powerprofile set <${PROFILES.join("|")}>`,
        );
      }
      return runArgv(["powerprofilesctl", "set", profile]);
    }
    default:
      return usageError(
        rt,
        `unknown action: "${action}"`,
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
