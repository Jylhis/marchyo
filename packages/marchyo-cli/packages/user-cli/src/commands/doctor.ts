import { existsSync, lstatSync, readFileSync } from "node:fs";
import { join } from "node:path";
import {
  type PluginLock,
  type Runtime,
  type State,
  captureArgv,
  commandAvailable,
  data,
  devPluginsDir,
  hyprlandAvailable,
  notifyNonceDir,
  readBakedToolPaths,
  readPluginLock,
  readState,
  shellConfigQmlPath,
  shellDevPluginsEnabled,
  shellInstalled,
  shellIpc,
} from "@marchyo/core";
import { type SheetEntry, keybindingsSheetPath } from "./menu.ts";
import { pendingPlugins } from "./plugin.ts";

// `marchyo doctor`: health checks for the live session. Each check is PASS,
// WARN, FAIL, or SKIP (not applicable on this host, e.g. no shell installed or
// not inside Hyprland). Exit 1 when any check fails, else 0; warnings do not
// fail the run.

export type CheckStatus = "pass" | "warn" | "fail" | "skip";
export type Check = { name: string; status: CheckStatus; detail: string };
export type DoctorReport = { ok: boolean; checks: Check[] };

const pass = (name: string, detail: string): Check => ({ name, status: "pass", detail });
const warn = (name: string, detail: string): Check => ({ name, status: "warn", detail });
const fail = (name: string, detail: string): Check => ({ name, status: "fail", detail });
const skip = (name: string, detail: string): Check => ({ name, status: "skip", detail });

// User units marchyo's Home Manager modules may install. Units this host
// does not have (LoadState=not-found) are left out of the report.
export const USER_UNITS = [
  "marchyo-shell.service",
  "waybar.service",
  "mako.service",
  "swayosd.service",
  "hyprpolkitagent.service",
  "hyprsunset.service",
  "vicinae.service",
] as const;

export function checkBakedToolPaths(
  installed: boolean,
  qmlPath: string | null,
  exists: (p: string) => boolean = existsSync,
): Check {
  const name = "shell tool paths";
  if (!installed) return skip(name, "marchyo-shell not installed");
  if (qmlPath === null) return fail(name, "generated Commons/Config.qml not found next to marchyo-shell");
  let tools: Record<string, string>;
  try {
    tools = readBakedToolPaths(qmlPath);
  } catch (e) {
    return fail(name, `cannot read ${qmlPath}: ${(e as Error).message}`);
  }
  const entries = Object.entries(tools);
  if (entries.length === 0) return fail(name, `no baked tool paths in ${qmlPath}`);
  const missing = entries.filter(([, p]) => !exists(p)).map(([k, p]) => `${k} (${p})`);
  return missing.length === 0
    ? pass(name, `${entries.length} baked paths present`)
    : fail(name, `missing: ${missing.join(", ")}`);
}

type ExtraPlugins = NonNullable<NonNullable<State["shell"]>["extraPlugins"]>;

// Every CLI-declared plugin should be baked into the installed shell at its
// pinned rev. Skipped without a lock (no shell, or one built before the lock)
// or without CLI-added plugins.
export function checkPluginLock(lock: PluginLock | null, declared: ExtraPlugins): Check {
  const name = "shell plugins";
  if (lock === null) return skip(name, "no plugins.lock.json in the installed shell");
  if (declared.length === 0) return skip(name, "no CLI-added plugins");
  const pending = pendingPlugins(declared, lock);
  return pending.length === 0
    ? pass(name, `${declared.length} CLI-added plugin${declared.length === 1 ? "" : "s"} built`)
    : warn(name, `declared but not built yet: ${pending.map((p) => p.id).join(", ")}; rebuild`);
}

async function checkPlugins(): Promise<Check> {
  const lock = readPluginLock();
  if (lock === null) return checkPluginLock(null, []);
  const state = await readState().catch(() => ({}) as State);
  return checkPluginLock(lock, state.shell?.extraPlugins ?? []);
}

// Panels whose shortcut `lib/keybinds.nix` must bind, keyed by the cheat
// sheet description.
export const REQUIRED_PANEL_BINDS = ["Ui gallery (developer)"] as const;

export function checkPanelBinds(installed: boolean, sheet: SheetEntry[] | null): Check {
  const name = "shell panel binds";
  if (!installed) return skip(name, "marchyo-shell not installed");
  if (sheet === null) return skip(name, "no keybindings.json (Hyprland binds not generated)");
  const missing = REQUIRED_PANEL_BINDS.filter(
    (d) => !sheet.some((e) => e.group === "Panels" && e.description === d),
  );
  return missing.length === 0
    ? pass(name, `${REQUIRED_PANEL_BINDS.length} required bind present`)
    : warn(name, `no bind for: ${missing.join(", ")}; rebuild`);
}

function readSheet(): SheetEntry[] | null {
  try {
    return JSON.parse(readFileSync(keybindingsSheetPath(), "utf8")) as SheetEntry[];
  } catch {
    return null;
  }
}

// The dev plugin loader is a development convenience: warn while it mounts
// unreviewed code.
export function checkDevPlugins(enabled: boolean, loaded: string[]): Check {
  const name = "dev plugins";
  if (!enabled) return skip(name, "dev plugin loader is off");
  return loaded.length === 0
    ? pass(name, "dev plugin loader is on, none loaded")
    : warn(name, `unreviewed code in the shell: ${loaded.join(", ")}`);
}

function devPluginIds(): string[] {
  try {
    const parsed = JSON.parse(readFileSync(join(devPluginsDir(), "index.json"), "utf8")) as {
      plugins?: { id?: string }[];
    };
    return (parsed.plugins ?? []).map((p) => p.id ?? "?");
  } catch {
    return [];
  }
}

async function checkHyprland(): Promise<Check> {
  const name = "hyprland ipc";
  if (!hyprlandAvailable()) return skip(name, "not inside a Hyprland session");
  if (!commandAvailable("hyprctl")) return fail(name, "hyprctl not found in PATH");
  const r = await captureArgv(["hyprctl", "-j", "version"]);
  if (r.code !== 0) return fail(name, `socket did not answer (hyprctl exit ${r.code})`);
  try {
    const v = (JSON.parse(r.stdout) as { version?: string }).version;
    return pass(name, `Hyprland ${v ?? "unknown version"} answered`);
  } catch {
    return fail(name, "socket answered with unparsable output");
  }
}

async function checkShell(): Promise<Check> {
  const name = "shell ipc";
  if (!shellInstalled()) return skip(name, "marchyo-shell not installed");
  try {
    const reply = await shellIpc("ping");
    return reply === "ok"
      ? pass(name, "shell answered ping")
      : fail(name, `unexpected ping reply: ${reply}`);
  } catch (e) {
    return fail(name, (e as Error).message);
  }
}

// The directory `marchyo notify` writes its one-time tokens to must be private
// to this user, or another account could mint a click command.
export function checkNotifyNonceDir(
  dir: string | null,
  uid: number | undefined = process.getuid?.(),
): Check {
  const name = "notification tokens";
  if (dir === null) return skip(name, "XDG_RUNTIME_DIR is not set");
  let st;
  try {
    st = lstatSync(dir);
  } catch {
    return skip(name, "no click-command notification sent yet");
  }
  if (!st.isDirectory()) return fail(name, `${dir} is not a plain directory`);
  if (uid !== undefined && st.uid !== uid) return fail(name, `${dir} belongs to another user`);
  if ((st.mode & 0o077) !== 0) {
    return fail(name, `${dir} is open to others (mode ${(st.mode & 0o777).toString(8)}); use 700`);
  }
  return pass(name, "private to this user");
}

async function checkNotifier(): Promise<Check> {
  const name = "notification service";
  if (!shellInstalled() || !commandAvailable("busctl")) {
    return skip(name, "marchyo-shell or busctl not available");
  }
  const r = await captureArgv(["busctl", "--user", "status", "org.freedesktop.Notifications"]);
  return r.code === 0
    ? pass(name, "a service owns org.freedesktop.Notifications")
    : warn(name, "nothing owns org.freedesktop.Notifications; is the shell running?");
}

// Parse `systemctl --user show -p Id,LoadState,ActiveState …` output: blank-
// line-separated property blocks, one per unit.
export function parseUnitStates(
  out: string,
): { id: string; load: string; active: string }[] {
  return out
    .split(/\n\s*\n/)
    .map((block) => {
      const props: Record<string, string> = {};
      for (const line of block.split("\n")) {
        const i = line.indexOf("=");
        if (i > 0) props[line.slice(0, i)] = line.slice(i + 1);
      }
      return {
        id: props.Id ?? "",
        load: props.LoadState ?? "",
        active: props.ActiveState ?? "",
      };
    })
    .filter((u) => u.id !== "");
}

async function checkUserUnits(): Promise<Check[]> {
  if (!commandAvailable("systemctl")) {
    return [skip("user services", "systemctl not found in PATH")];
  }
  const r = await captureArgv([
    "systemctl",
    "--user",
    "show",
    "-p",
    "Id,LoadState,ActiveState",
    ...USER_UNITS,
  ]);
  if (r.code !== 0) {
    return [skip("user services", "systemd user manager unreachable")];
  }
  return parseUnitStates(r.stdout)
    .filter((u) => u.load !== "not-found")
    .map((u) =>
      u.active === "active"
        ? pass(`service ${u.id}`, "active")
        : fail(`service ${u.id}`, u.active || "unknown state"),
    );
}

export async function collectChecks(): Promise<Check[]> {
  const [hypr, shell, plugins, units, notifier] = await Promise.all([
    checkHyprland(),
    checkShell(),
    checkPlugins(),
    checkUserUnits(),
    checkNotifier(),
  ]);
  return [
    checkBakedToolPaths(shellInstalled(), shellConfigQmlPath()),
    checkPanelBinds(shellInstalled(), readSheet()),
    checkDevPlugins(shellInstalled() && shellDevPluginsEnabled(), devPluginIds()),
    hypr,
    shell,
    plugins,
    ...units,
    notifier,
    checkNotifyNonceDir(notifyNonceDir()),
  ];
}

export function renderDoctor(report: DoctorReport): string {
  const width = Math.max(...report.checks.map((c) => c.name.length));
  const label = { pass: "PASS", warn: "WARN", fail: "FAIL", skip: "SKIP" } as const;
  const lines = report.checks.map(
    (c) => `${label[c.status]}  ${c.name.padEnd(width)}  ${c.detail}`,
  );
  const failed = report.checks.filter((c) => c.status === "fail").length;
  const warned = report.checks.filter((c) => c.status === "warn").length;
  const warnings = warned === 0 ? "" : ` (${warned} warning${warned === 1 ? "" : "s"})`;
  lines.push("");
  lines.push(
    (failed === 0
      ? "all checks passed"
      : `${failed} check${failed === 1 ? "" : "s"} failed`) + warnings,
  );
  return lines.join("\n");
}

export async function runDoctor(rt: Runtime): Promise<number> {
  const checks = await collectChecks();
  const report: DoctorReport = {
    ok: checks.every((c) => c.status !== "fail"),
    checks,
  };
  data(rt, report, () => renderDoctor(report));
  return report.ok ? 0 : 1;
}
