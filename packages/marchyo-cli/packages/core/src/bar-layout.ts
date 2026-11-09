import { existsSync, readFileSync } from "node:fs";
import { mkdir, rename, rm, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

// Runtime edits of the bar layout. The shell applies them over the layout
// shell.json resolves (shell/Commons/BarOverlay.js owns the semantics), so the
// CLI never needs the base layout: it only records ops.
export const BAR_SECTIONS = ["left", "centerBegin", "center", "centerEnd", "right"] as const;
export type BarSection = (typeof BAR_SECTIONS)[number];

export const SEPARATOR_ID = "marchyo.separator";
export const MAX_BAR_OPS = 200;

export type BarOp =
  | { op: "put"; id: string; section: BarSection; at?: number }
  | { op: "remove"; id: string }
  | { op: "set"; section: BarSection; ids: string[] }
  | { op: "shift"; id: string; by: number };

export function barLayoutPath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo", "shell", "bar-layout.json");
}

export function isBarId(id: unknown): id is string {
  return typeof id === "string" && /^[A-Za-z0-9._-]{1,96}$/.test(id);
}

export function isBarSection(s: unknown): s is BarSection {
  return BAR_SECTIONS.includes(s as BarSection);
}

// Same filter as the shell's BarOverlay.parseOps: a hand-edited file never
// reaches the shell with a malformed op.
export function parseBarOps(raw: unknown): BarOp[] {
  const list =
    raw !== null && typeof raw === "object" && Array.isArray((raw as { ops?: unknown }).ops)
      ? ((raw as { ops: unknown[] }).ops)
      : [];
  const out: BarOp[] = [];
  for (const item of list) {
    if (out.length >= MAX_BAR_OPS) break;
    if (item === null || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    if (o.op === "put" && isBarId(o.id) && isBarSection(o.section)) {
      const put: BarOp = { op: "put", id: o.id, section: o.section };
      if (typeof o.at === "number" && Number.isFinite(o.at) && o.at >= 0) {
        put.at = Math.floor(o.at);
      }
      out.push(put);
    } else if (o.op === "remove" && isBarId(o.id)) {
      out.push({ op: "remove", id: o.id });
    } else if (
      o.op === "set" &&
      isBarSection(o.section) &&
      Array.isArray(o.ids) &&
      o.ids.every(isBarId)
    ) {
      out.push({ op: "set", section: o.section, ids: [...o.ids] });
    } else if (o.op === "shift" && isBarId(o.id) && typeof o.by === "number" && Number.isFinite(o.by)) {
      out.push({ op: "shift", id: o.id, by: Math.trunc(o.by) });
    }
  }
  return out;
}

export function readBarOps(path: string = barLayoutPath()): BarOp[] {
  if (!existsSync(path)) return [];
  try {
    return parseBarOps(JSON.parse(readFileSync(path, "utf8")));
  } catch {
    return [];
  }
}

// Append `op`, dropping earlier ops that the new one makes redundant (a later
// put or remove of the same non-separator id) and keeping the list bounded.
export function appendBarOp(ops: BarOp[], op: BarOp): BarOp[] {
  const concerns = (o: BarOp): boolean =>
    "id" in o && o.id === ("id" in op ? op.id : "") && o.id !== SEPARATOR_ID;
  const redundant =
    (op.op === "put" || op.op === "remove") && op.id !== SEPARATOR_ID
      ? (o: BarOp) => (o.op === "put" || o.op === "remove") && concerns(o)
      : () => false;
  const next = [...ops.filter((o) => !redundant(o)), op];
  return next.slice(-MAX_BAR_OPS);
}

// Atomic (temp file, then rename) so the shell's watcher never reads a torn
// file. An empty op list deletes the file.
export async function writeBarOps(
  ops: BarOp[],
  path: string = barLayoutPath(),
): Promise<void> {
  if (ops.length === 0) {
    await rm(path, { force: true });
    return;
  }
  await mkdir(dirname(path), { recursive: true });
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, `${JSON.stringify({ ops })}\n`);
  await rename(tmp, path);
}
