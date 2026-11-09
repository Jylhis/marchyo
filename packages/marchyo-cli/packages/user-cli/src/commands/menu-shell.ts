import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { shellIpc } from "@marchyo/core";

// The shell-menu side of `marchyo menu`: route handling, omarchy-style dmenu
// rows, and the file transport that hands a select/input request to the
// marchyo shell and waits for its answer.

export type TuiTarget = "power" | "appearance" | "main";

// Dotted lower-case ids: "Appearance/Theme", " capture. " -> "appearance.theme",
// "capture". Empty for the root.
export function normalizeRoute(raw: string | undefined): string {
  if (raw === undefined) return "";
  return raw
    .toLowerCase()
    .split(/[./\s]+/)
    .map((part) => part.replace(/[^a-z0-9_-]/g, ""))
    .filter((part) => part !== "")
    .join(".");
}

export function tuiTarget(route: string): TuiTarget {
  const head = route.split(".")[0];
  if (route === "power" || route === "system") return "power";
  if (head === "appearance") return "appearance";
  return "main";
}

export type MenuRow = { glyph?: string; label: string; subtext?: string };

function isGlyph(field: string): boolean {
  return [...field].length <= 2;
}

// One row per line, fields split by TAB: label | glyph label | label subtext |
// glyph label subtext. With two fields the first is a glyph when it has at
// most two code points. Blank lines and rows without a label are dropped.
export function parseRows(text: string): MenuRow[] {
  const rows: MenuRow[] = [];
  for (const raw of text.split("\n")) {
    const line = raw.replace(/\r$/, "");
    if (line === "") continue;
    const fields = line.split("\t");
    let row: MenuRow;
    if (fields.length === 1) {
      row = { label: fields[0]! };
    } else if (fields.length === 2) {
      row = isGlyph(fields[0]!)
        ? { glyph: fields[0]!, label: fields[1]! }
        : { label: fields[0]!, subtext: fields[1]! };
    } else {
      row = { glyph: fields[0]!, label: fields[1]!, subtext: fields.slice(2).join("\t") };
    }
    if (row.label === "") continue;
    rows.push(row);
  }
  return rows;
}

// What a chosen row prints: the label alone, or label TAB subtext. The glyph
// is never returned.
export function rowValue(row: MenuRow): string {
  return row.subtext === undefined || row.subtext === ""
    ? row.label
    : `${row.label}\t${row.subtext}`;
}

export type MenuRequestInput = {
  prompt?: string;
  rows?: MenuRow[];
  multiple?: boolean;
  selected?: string[];
  width?: number;
  maxHeight?: number;
  onChange?: string[];
  changeKey?: string;
};

export type MenuRequest = {
  mode: "select" | "input";
  prompt?: string;
  rows?: MenuRow[];
  multiple?: true;
  selected?: string[];
  width?: number;
  maxHeight?: number;
  onChange?: string[];
  changeKey?: string;
};

// Unset fields are left out so the shell applies its own defaults.
export function buildMenuRequest(
  mode: "select" | "input",
  input: MenuRequestInput,
): MenuRequest {
  const req: MenuRequest = { mode };
  if (input.prompt !== undefined) req.prompt = input.prompt;
  if (mode === "select") {
    req.rows = (input.rows ?? []).map((r) => ({
      ...(r.glyph !== undefined ? { glyph: r.glyph } : {}),
      label: r.label,
      ...(r.subtext !== undefined ? { subtext: r.subtext } : {}),
    }));
    if (input.multiple === true) req.multiple = true;
    if (input.selected !== undefined && input.selected.length > 0) req.selected = input.selected;
    if (input.onChange !== undefined && input.onChange.length > 0) req.onChange = input.onChange;
    if (input.changeKey !== undefined) req.changeKey = input.changeKey;
    if (input.maxHeight !== undefined) req.maxHeight = input.maxHeight;
  }
  if (input.width !== undefined) req.width = input.width;
  return req;
}

export type MenuOutcome =
  | { kind: "chosen"; text: string }
  | { kind: "cancelled" }
  | { kind: "unreachable"; reason: string };

export type MenuTransportDeps = {
  ipc?: (fn: string, ...args: string[]) => Promise<string>;
  runtimeDir?: string | undefined;
  sleep?: (ms: number) => Promise<void>;
  pollMs?: number;
  timeoutMs?: number;
  id?: string;
};

export const MENU_POLL_MS = 50;
export const MENU_TIMEOUT_MS = 10 * 60 * 1000;

function reason(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

// Writes the request file, calls the shell's menuRequest, then waits for the
// shell to create <id>.out (the chosen text) and, last, <id>.done. The three
// files are always removed. A missing or empty .out means cancel.
export async function requestMenu(
  request: MenuRequest,
  deps: MenuTransportDeps = {},
): Promise<MenuOutcome> {
  const runtime = deps.runtimeDir ?? process.env.XDG_RUNTIME_DIR;
  if (runtime === undefined || runtime === "") {
    return { kind: "unreachable", reason: "XDG_RUNTIME_DIR is not set" };
  }
  const ipc = deps.ipc ?? shellIpc;
  const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const pollMs = deps.pollMs ?? MENU_POLL_MS;
  const polls = Math.max(1, Math.ceil((deps.timeoutMs ?? MENU_TIMEOUT_MS) / pollMs));

  const dir = resolve(runtime, "marchyo", "menu");
  const base = join(dir, deps.id ?? crypto.randomUUID());
  const files = { req: `${base}.json`, out: `${base}.out`, done: `${base}.done` };
  try {
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    chmodSync(dir, 0o700);
    writeFileSync(files.req, JSON.stringify(request), { mode: 0o600 });
    try {
      await ipc("menuRequest", files.req);
    } catch (e) {
      return { kind: "unreachable", reason: reason(e) };
    }
    for (let i = 0; i < polls; i++) {
      if (existsSync(files.done)) return readOutcome(files.out);
      await sleep(pollMs);
    }
    return { kind: "cancelled" };
  } catch (e) {
    return { kind: "unreachable", reason: reason(e) };
  } finally {
    for (const f of Object.values(files)) rmSync(f, { force: true });
  }
}

function readOutcome(path: string): MenuOutcome {
  let text = "";
  try {
    text = readFileSync(path, "utf8");
  } catch {
    return { kind: "cancelled" };
  }
  text = text.replace(/\r?\n$/, "");
  return text === "" ? { kind: "cancelled" } : { kind: "chosen", text };
}

// The text printed for a chosen value. Multiple selections print a JSON array;
// the shell may write that array itself or one value per line.
export function formatChoice(text: string, multiple: boolean): string {
  if (!multiple) return text;
  try {
    const parsed: unknown = JSON.parse(text);
    if (Array.isArray(parsed) && parsed.every((v) => typeof v === "string")) {
      return JSON.stringify(parsed);
    }
  } catch {
    // not JSON: one value per line
  }
  return JSON.stringify(text.split("\n").filter((l) => l !== ""));
}

// argv for the terminal fallback of `menu select`.
export function gumChooseArgv(
  prompt: string | undefined,
  rows: MenuRow[],
  multiple: boolean,
  selected: string[],
): string[] {
  const argv = ["gum", "choose"];
  if (prompt !== undefined) argv.push("--header", prompt);
  if (multiple) argv.push("--no-limit");
  const preselect = rows.filter((r) => selected.includes(r.label)).map(gumDisplay);
  if (preselect.length > 0) argv.push("--selected", preselect.join(","));
  return [...argv, ...rows.map(gumDisplay)];
}

export function gumDisplay(row: MenuRow): string {
  return [row.glyph, row.label, row.subtext].filter((s) => s !== undefined && s !== "").join("  ");
}
