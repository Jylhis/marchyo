import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  err,
  hyprctlKeywordArgv,
  hyprlandAvailable,
  runArgv,
  usageError,
} from "@marchyo/core";

// Launch / focus-or-launch / monitor helpers / cursor zoom (F3.2),
// absorbing marchyo-file-manager-cwd, marchyo-monitor-scale-cycle,
// marchyo-laptop-display-toggle, and marchyo-zoom.

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

// Focused terminal's working directory: active window PID → first child
// (the shell) → /proc/<pid>/cwd; $HOME fallback.
async function focusedCwd(): Promise<string> {
  const home = homedir();
  if (!hyprlandAvailable()) return home;
  const active = await captureArgv(["hyprctl", "activewindow", "-j"]);
  if (active.code !== 0) return home;
  let pid: number | null = null;
  try {
    pid = (JSON.parse(active.stdout) as { pid?: number }).pid ?? null;
  } catch {
    return home;
  }
  if (!pid || pid <= 0) return home;
  const child = await captureArgv(["pgrep", "-P", String(pid)]);
  const candidates = [
    ...child.stdout.split("\n").filter((l) => l.trim() !== "").slice(0, 1),
    String(pid),
  ];
  for (const p of candidates) {
    try {
      return realpathSync(`/proc/${p.trim()}/cwd`);
    } catch {
      // dead or unreadable; try the next candidate
    }
  }
  return home;
}

export async function runLaunch(
  rt: Runtime,
  app: string,
  args: string[],
): Promise<number> {
  // `launch file-manager` opens the default file manager at the focused
  // terminal's cwd (the old marchyo-file-manager-cwd behavior) via
  // xdg-open, which resolves the configured default.
  if (app === "file-manager") {
    const dir = await focusedCwd();
    return runArgv(["xdg-open", dir]);
  }
  if (!commandAvailable(app)) {
    err(rt, `${app} not found in PATH`);
    return 1;
  }
  return detach([app, ...args]) ? 0 : 1;
}

// Focus an existing window of the class, else launch the command.
export async function runFocusOrLaunch(
  rt: Runtime,
  className: string,
  command: string[],
): Promise<number> {
  if (hyprlandAvailable()) {
    const clients = await captureArgv(["hyprctl", "clients", "-j"]);
    if (clients.code === 0) {
      try {
        const list = JSON.parse(clients.stdout) as Array<{ class?: string }>;
        const match = list.find(
          (c) => (c.class ?? "").toLowerCase() === className.toLowerCase(),
        );
        if (match) {
          return runArgv([
            "hyprctl",
            "dispatch",
            "focuswindow",
            `class:${className}`,
          ]);
        }
      } catch {
        // fall through to launch
      }
    }
  }
  const argv = command.length > 0 ? command : [className];
  return runLaunch(rt, argv[0]!, argv.slice(1));
}

// Cursor zoom (absorbed from marchyo-zoom): step cursor:zoom_factor.
export async function runZoom(rt: Runtime, direction: string): Promise<number> {
  if (!["in", "out", "reset"].includes(direction)) {
    return usageError(rt, `invalid zoom direction: "${direction}"`, "marchyo zoom in|out|reset");
  }
  if (!hyprlandAvailable()) {
    err(rt, "not inside a Hyprland session");
    return 1;
  }
  let current = 1;
  const r = await captureArgv(["hyprctl", "getoption", "-j", "cursor:zoom_factor"]);
  if (r.code === 0) {
    try {
      current = (JSON.parse(r.stdout) as { float?: number }).float ?? 1;
    } catch {
      current = 1;
    }
  }
  const next =
    direction === "in"
      ? current + 0.5
      : direction === "out"
        ? Math.max(1, current - 0.5)
        : 1;
  return runArgv(hyprctlKeywordArgv("cursor:zoom_factor", next.toFixed(2)));
}

// Monitor helpers (absorbed from marchyo-monitor-scale-cycle and
// marchyo-laptop-display-toggle).
export async function runMonitorScaleCycle(rt: Runtime): Promise<number> {
  if (!hyprlandAvailable()) {
    err(rt, "not inside a Hyprland session");
    return 1;
  }
  const r = await captureArgv(["hyprctl", "monitors", "-j"]);
  if (r.code !== 0) {
    err(rt, "hyprctl monitors failed");
    return 1;
  }
  type Mon = {
    name: string;
    focused?: boolean;
    scale: number;
    width: number;
    height: number;
    refreshRate: number;
    x: number;
    y: number;
  };
  let mon: Mon | undefined;
  try {
    mon = (JSON.parse(r.stdout) as Mon[]).find((m) => m.focused);
  } catch {
    mon = undefined;
  }
  if (!mon) {
    err(rt, "no focused monitor found");
    return 1;
  }
  // 1 -> 1.25 -> 1.5 -> 1.75 -> 2 -> 1; off-cycle values snap back to 1.
  // Hyprland clamps scales to integer pixel sizes, so panels may skip steps.
  const steps: Record<string, string> = {
    "1": "1.25",
    "1.25": "1.5",
    "1.5": "1.75",
    "1.75": "2",
  };
  const next = steps[String(mon.scale)] ?? "1";
  return runArgv(
    hyprctlKeywordArgv(
      "monitor",
      `${mon.name},${mon.width}x${mon.height}@${mon.refreshRate},${mon.x}x${mon.y},${next}`,
    ),
  );
}

export async function runMonitorLaptopToggle(rt: Runtime): Promise<number> {
  if (!hyprlandAvailable()) {
    err(rt, "not inside a Hyprland session");
    return 1;
  }
  const r = await captureArgv(["hyprctl", "monitors", "all", "-j"]);
  if (r.code !== 0) {
    err(rt, "hyprctl monitors failed");
    return 1;
  }
  type Mon = {
    name: string;
    disabled?: boolean;
    width: number;
    height: number;
    refreshRate: number;
    x: number;
    y: number;
    scale: number;
  };
  let mon: Mon | undefined;
  try {
    mon = (JSON.parse(r.stdout) as Mon[]).find((m) => /^eDP/.test(m.name));
  } catch {
    mon = undefined;
  }
  if (!mon) {
    err(rt, "no laptop display (eDP*) found");
    return 1;
  }
  if (mon.disabled) {
    // A long-disabled output can report zeroed fields; fall back to
    // preferred/auto instead of feeding Hyprland a 0x0 mode.
    let mode = "preferred";
    let pos = "auto";
    const scale = mon.scale > 0 ? String(mon.scale) : "auto";
    if (mon.width > 0 && mon.height > 0) {
      mode =
        mon.refreshRate > 0
          ? `${mon.width}x${mon.height}@${mon.refreshRate}`
          : `${mon.width}x${mon.height}`;
      pos = `${mon.x}x${mon.y}`;
    }
    return runArgv(
      hyprctlKeywordArgv("monitor", `${mon.name},${mode},${pos},${scale}`),
    );
  }
  return runArgv(hyprctlKeywordArgv("monitor", `${mon.name},disable`));
}
