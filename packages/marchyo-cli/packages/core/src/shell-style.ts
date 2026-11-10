import { existsSync, readFileSync } from "node:fs";
import { mkdir, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

// Runtime style overrides the CLI writes and the shell watches
// (shell/Services). Every key is optional: an absent key is the declarative
// default baked into the shell package.
export const BAR_POSITIONS = ["top", "bottom"] as const;
export const BAR_BACKGROUNDS = ["opaque", "glassy", "clear"] as const;
export type BarPosition = (typeof BAR_POSITIONS)[number];
export type BarBackground = (typeof BAR_BACKGROUNDS)[number];

export type ShellStyle = {
  reduceMotion?: boolean;
  uiFont?: string;
  barPosition?: BarPosition;
  barBackground?: BarBackground;
};

export type ShellStylePatch = {
  [K in keyof ShellStyle]?: ShellStyle[K] | null;
};

export function shellStylePath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo", "shell", "style.json");
}

// Unknown keys and wrongly typed values are dropped, so a hand-edited file
// never reaches the shell with a bad value.
export function parseShellStyle(raw: unknown): ShellStyle {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return {};
  const r = raw as Record<string, unknown>;
  const style: ShellStyle = {};
  if (typeof r.reduceMotion === "boolean") style.reduceMotion = r.reduceMotion;
  if (typeof r.uiFont === "string" && r.uiFont !== "") style.uiFont = r.uiFont;
  if (BAR_POSITIONS.includes(r.barPosition as never)) {
    style.barPosition = r.barPosition as BarPosition;
  }
  if (BAR_BACKGROUNDS.includes(r.barBackground as never)) {
    style.barBackground = r.barBackground as BarBackground;
  }
  return style;
}

export function readShellStyle(path: string = shellStylePath()): ShellStyle {
  if (!existsSync(path)) return {};
  try {
    return parseShellStyle(JSON.parse(readFileSync(path, "utf8")));
  } catch {
    return {};
  }
}

// Merge `patch` into the file: a null value deletes its key. Atomic (temp
// file, then rename) so the shell's file watcher never reads a torn file.
export async function patchShellStyle(
  patch: ShellStylePatch,
  path: string = shellStylePath(),
): Promise<ShellStyle> {
  const next: Record<string, unknown> = { ...readShellStyle(path) };
  for (const [key, value] of Object.entries(patch)) {
    if (value === null || value === undefined) delete next[key];
    else next[key] = value;
  }
  const style = parseShellStyle(next);
  await mkdir(dirname(path), { recursive: true });
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, `${JSON.stringify(style)}\n`);
  await rename(tmp, path);
  return style;
}
