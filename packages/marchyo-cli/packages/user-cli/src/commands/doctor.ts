import { existsSync } from "node:fs";
import {
  type Runtime,
  captureArgv,
  commandAvailable,
  data,
  hyprlandAvailable,
  readBakedToolPaths,
  shellConfigQmlPath,
  shellInstalled,
  shellIpc,
} from "@marchyo/core";

// `marchyo doctor`: health checks for the live session. Each check is PASS,
// FAIL, or SKIP (not applicable on this host, e.g. no shell installed or not
// inside Hyprland). Exit 1 when any check fails, else 0.

export type CheckStatus = "pass" | "fail" | "skip";
export type Check = { name: string; status: CheckStatus; detail: string };
export type DoctorReport = { ok: boolean; checks: Check[] };

const pass = (name: string, detail: string): Check => ({ name, status: "pass", detail });
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
    return fail(name, "socket answered with unparseable output");
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
  const [hypr, shell, units] = await Promise.all([
    checkHyprland(),
    checkShell(),
    checkUserUnits(),
  ]);
  return [
    checkBakedToolPaths(shellInstalled(), shellConfigQmlPath()),
    hypr,
    shell,
    ...units,
  ];
}

export function renderDoctor(report: DoctorReport): string {
  const width = Math.max(...report.checks.map((c) => c.name.length));
  const label = { pass: "PASS", fail: "FAIL", skip: "SKIP" } as const;
  const lines = report.checks.map(
    (c) => `${label[c.status]}  ${c.name.padEnd(width)}  ${c.detail}`,
  );
  const failed = report.checks.filter((c) => c.status === "fail").length;
  lines.push("");
  lines.push(
    failed === 0
      ? "all checks passed"
      : `${failed} check${failed === 1 ? "" : "s"} failed`,
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
