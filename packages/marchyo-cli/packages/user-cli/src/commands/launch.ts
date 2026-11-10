import { realpathSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  err,
  hyprctlDispatchArgv,
  hyprctlKeywordArgv,
  hyprlandAvailable,
  luaString,
  ok,
  runArgv,
  usageError,
  tr,
} from "@marchyo/core";

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

// Aliases the omarchy-launch-* shims use: the default browser, a terminal at
// the focused directory, and a floating terminal. Null for any other name.
export async function aliasArgv(app: string, args: string[]): Promise<string[] | null> {
  if (app === "browser") {
    if (args.length > 0) return ["xdg-open", ...args];
    const r = await captureArgv(["xdg-settings", "get", "default-web-browser"]);
    const desktop = r.stdout.trim();
    return r.code === 0 && desktop !== "" ? ["gtk-launch", desktop] : null;
  }
  if (app === "terminal" || app === "floating-terminal") {
    const dir = await focusedCwd();
    const term = commandAvailable("xdg-terminal-exec") ? ["xdg-terminal-exec"] : ["ghostty"];
    const floating = app === "floating-terminal" ? ["--class=org.marchyo.floating"] : [];
    const dirFlag = term[0] === "ghostty" ? [`--working-directory=${dir}`] : [`--dir=${dir}`];
    const cmd = args.length > 0 ? ["-e", ...args] : [];
    return [...term, ...floating, ...dirFlag, ...cmd];
  }
  return null;
}

export async function runLaunch(
  rt: Runtime,
  app: string,
  args: string[],
): Promise<number> {
  // `launch file-manager` opens the default file manager at the focused
  // terminal's cwd via xdg-open, which resolves the configured default.
  if (app === "file-manager") {
    const dir = await focusedCwd();
    return runArgv(["xdg-open", dir]);
  }
  const alias = await aliasArgv(app, args);
  if (alias !== null) return detach(alias) ? 0 : 1;
  if (!commandAvailable(app)) {
    err(rt, tr("launch.notFoundInPath", app));
    return 1;
  }
  return detach([app, ...args]) ? 0 : 1;
}

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
          return runArgv(
            hyprctlDispatchArgv(
              `hl.dsp.focus({ window = ${luaString(`class:${className}`)} })`,
            ),
          );
        }
      } catch {
        // fall through to launch
      }
    }
  }
  const argv = command.length > 0 ? command : [className];
  return runLaunch(rt, argv[0]!, argv.slice(1));
}

export async function runZoom(rt: Runtime, direction: string): Promise<number> {
  if (!["in", "out", "reset"].includes(direction)) {
    return usageError(rt, tr("launch.invalidZoomDirection", direction), "marchyo zoom in|out|reset");
  }
  if (!hyprlandAvailable()) {
    err(rt, tr("launch.notInsideHyprlandSession"));
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

export async function runMonitorScaleCycle(rt: Runtime): Promise<number> {
  if (!hyprlandAvailable()) {
    err(rt, tr("launch.notInsideHyprlandSession"));
    return 1;
  }
  const r = await captureArgv(["hyprctl", "monitors", "-j"]);
  if (r.code !== 0) {
    err(rt, tr("launch.hyprctlMonitorsFailed"));
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
    err(rt, tr("launch.noFocusedMonitorFound"));
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

async function listMonitors(rt: Runtime): Promise<HyprMonitor[] | null> {
  if (!hyprlandAvailable()) {
    err(rt, tr("launch.notInsideHyprlandSession"));
    return null;
  }
  const r = await captureArgv(["hyprctl", "monitors", "all", "-j"]);
  if (r.code !== 0) {
    err(rt, tr("launch.hyprctlMonitorsFailed"));
    return null;
  }
  try {
    return JSON.parse(r.stdout) as HyprMonitor[];
  } catch {
    return [];
  }
}

function enableLaptopPanel(mon: HyprMonitor): Promise<number> {
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

const disableLaptopPanel = (mon: HyprMonitor): Promise<number> =>
  runArgv(hyprctlKeywordArgv("monitor", `${mon.name},disable`));

export async function runMonitorLaptopToggle(rt: Runtime): Promise<number> {
  const mons = await listMonitors(rt);
  if (!mons) return 1;
  const mon = mons.find((m) => /^eDP/.test(m.name));
  if (!mon) {
    err(rt, tr("launch.noLaptopDisplayEdpFound"));
    return 1;
  }
  return mon.disabled ? enableLaptopPanel(mon) : disableLaptopPanel(mon);
}

// Lid switch handler. "on" (lid closed) turns the internal panel off only
// while an external display is enabled; "off" (lid open) turns it back on.
export async function runMonitorClamshell(
  rt: Runtime,
  state: string,
): Promise<number> {
  if (state !== "on" && state !== "off") {
    return usageError(rt, tr("launch.clamshellStateMustBeOn"));
  }
  const mons = await listMonitors(rt);
  if (!mons) return 1;
  const mon = mons.find((m) => /^eDP/.test(m.name));
  if (!mon) return 0;
  if (state === "off") return mon.disabled ? enableLaptopPanel(mon) : 0;
  const external = mons.some(
    (m) => m !== mon && m.name !== "FALLBACK" && !m.disabled && !/^eDP/.test(m.name),
  );
  return external && !mon.disabled ? disableLaptopPanel(mon) : 0;
}

// $XDG_STATE_HOME/marchyo/monitors: the per-monitor workspace cache written by
// modules/home/hyprland-monitor-workspaces.lua.
export function monitorWorkspacesStateFiles(env: NodeJS.ProcessEnv = process.env): string[] {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  const dir = join(base, "marchyo", "monitors");
  return [join(dir, "workspaces"), join(dir, "workspaces-merged")];
}

// Forget every monitor's workspace block. A config reload re-runs the Lua
// module with an empty cache, which assigns blocks to the monitors plugged in
// now.
export async function runMonitorWorkspacesReset(rt: Runtime): Promise<number> {
  for (const file of monitorWorkspacesStateFiles()) {
    try {
      rmSync(file, { force: true });
    } catch (e) {
      err(rt, tr("launch.couldNotRemove", file, (e as Error).message));
      return 1;
    }
  }
  if (hyprlandAvailable()) {
    const code = await runArgv(["hyprctl", "reload"]);
    if (code !== 0) return code;
  }
  ok(rt, tr("launch.monitorWorkspaceBlocksReset"));
  return 0;
}

// $XDG_STATE_HOME/marchyo/monitors/settings: the display panel's saved
// settings, applied by modules/home/hyprland-monitor-settings.lua after
// marchyo.monitors. Runtime state: it survives rebuilds until it is reset.
export function monitorSettingsFile(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo", "monitors", "settings");
}

// Forget the display panel's saved settings; marchyo.monitors alone decides
// again after the reload.
export async function runMonitorReset(rt: Runtime): Promise<number> {
  const file = monitorSettingsFile();
  try {
    rmSync(file, { force: true });
  } catch (e) {
    err(rt, tr("launch.couldNotRemove", file, (e as Error).message));
    return 1;
  }
  if (hyprlandAvailable()) {
    const code = await runArgv(["hyprctl", "reload"]);
    if (code !== 0) return code;
  }
  ok(rt, tr("launch.savedDisplaySettingsReset"));
  return 0;
}

export type HyprMonitor = {
  id?: number;
  name: string;
  disabled?: boolean;
  width: number;
  height: number;
  refreshRate: number;
  x: number;
  y: number;
  scale: number;
  transform?: number;
  mirrorOf?: number | string;
};

const SAFE_OUTPUT = /^[A-Za-z0-9._-]+$/;

function nixNumber(n: number): string {
  return String(Number(n.toFixed(2)));
}

// `marchyo.monitors` entries for the layout `hyprctl monitors all -j`
// reports: the mode, position, scale and rotation now in effect, a mirrored
// output as extraSettings.mirror, a disabled one as enable = false.
export function monitorNixSnippet(monitors: HyprMonitor[]): string {
  const names = new Map<string, string>();
  for (const m of monitors) names.set(String(m.id), m.name);
  const entries: string[] = [];
  for (const m of monitors) {
    if (!SAFE_OUTPUT.test(m.name)) continue;
    const lines = [`    output = "${m.name}";`];
    if (m.disabled) {
      lines.push("    enable = false;");
    } else {
      lines.push(
        `    mode = "${m.width}x${m.height}@${nixNumber(m.refreshRate)}";`,
        `    position = "${Math.round(m.x)}x${Math.round(m.y)}";`,
        `    scale = ${nixNumber(m.scale)};`,
      );
      if ((m.transform ?? 0) !== 0) lines.push(`    transform = ${m.transform};`);
      const mirrored =
        m.mirrorOf === undefined || m.mirrorOf === "none"
          ? undefined
          : names.get(String(m.mirrorOf));
      if (mirrored && SAFE_OUTPUT.test(mirrored)) {
        lines.push(`    extraSettings.mirror = "${mirrored}";`);
      }
    }
    entries.push(`  {\n${lines.join("\n")}\n  }`);
  }
  return `marchyo.monitors = [\n${entries.join("\n")}\n];\n`;
}

// Print the current layout as a marchyo.monitors snippet to paste into the
// configuration.
export async function runMonitorSave(
  rt: Runtime,
  opts: { nix?: boolean },
): Promise<number> {
  if (!opts.nix) {
    return usageError(rt, tr("launch.noOutputFormatGiven"), "marchyo monitor save --nix");
  }
  if (!hyprlandAvailable()) {
    err(rt, tr("launch.notInsideHyprlandSession"));
    return 1;
  }
  const r = await captureArgv(["hyprctl", "monitors", "all", "-j"]);
  if (r.code !== 0) {
    err(rt, tr("launch.hyprctlMonitorsFailed"));
    return 1;
  }
  let monitors: HyprMonitor[];
  try {
    monitors = JSON.parse(r.stdout) as HyprMonitor[];
  } catch {
    err(rt, tr("launch.couldNotReadTheMonitor"));
    return 1;
  }
  process.stdout.write(monitorNixSnippet(monitors));
  return 0;
}
