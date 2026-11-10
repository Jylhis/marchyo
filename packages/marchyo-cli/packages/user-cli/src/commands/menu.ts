import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  type Runtime,
  ShellIpcError,
  captureArgv,
  commandAvailable,
  err,
  info,
  readThemeManifest,
  runArgv,
  shellInstalled,
  shellIpc,
  themeAtPointer,
  menuLabel,
  usageError,
  tr,
} from "@marchyo/core";
import {
  cyclePowerProfile,
  runHibernate,
  runLock,
  runLockSuspend,
  runLogout,
  runReboot,
  runRebootFirmware,
  runShutdown,
  runSuspend,
} from "./power.ts";
import { runCaptureColor, runCaptureRecord, runCaptureScreenshot } from "./capture.ts";
import { runShellReload } from "./shell.ts";
import { runBgNext, runThemeSet } from "./theme.ts";
import { runFontSet } from "./font.ts";
import { runToggle } from "./toggle.ts";
import {
  CORNER_MODES,
  TRANSPARENCY_MODES,
  runThemeCorners,
  runThemeTransparency,
} from "./appearance.ts";
import { runShare } from "./utilities.ts";
import {
  type MenuOutcome,
  type MenuRow,
  type MenuTransportDeps,
  buildMenuRequest,
  formatChoice,
  gumChooseArgv,
  gumDisplay,
  normalizeRoute,
  parseRows,
  requestMenu,
  rowValue,
  tuiTarget,
} from "./menu-shell.ts";

// The gum-TUI menus and the fzf keybindings cheatsheet. The presentation
// stays gum/fzf in a floating ghostty; every dispatched action is a marchyo
// command.

// gum renders its UI on the tty (stderr) and prints the selection to
// stdout — so pipe stdout only. A cancelled prompt exits non-zero.
export async function gumChoose(
  header: string,
  options: string[],
): Promise<string | null> {
  try {
    const shown = options.map(menuLabel);
    const proc = Bun.spawn(["gum", "choose", "--header", menuLabel(header), ...shown], {
      stdout: "pipe",
      stderr: "inherit",
      stdin: "inherit",
    });
    const code = await proc.exited;
    const out = await new Response(proc.stdout).text();
    if (code !== 0) return null;
    const choice = out.trim();
    if (choice === "") return null;
    const index = shown.indexOf(choice);
    return index >= 0 ? options[index]! : choice;
  } catch {
    return null;
  }
}

// Prompt for a line of input; null on cancel/empty.
export async function gumInput(
  prompt: string,
  placeholder: string,
  initial?: string,
): Promise<string | null> {
  try {
    const argv = ["gum", "input", "--prompt", prompt, "--placeholder", placeholder];
    if (initial !== undefined) argv.push("--value", initial);
    const proc = Bun.spawn(argv, {
      stdout: "pipe",
      stderr: "inherit",
      stdin: "inherit",
    });
    const code = await proc.exited;
    const out = (await new Response(proc.stdout).text()).trim();
    if (code !== 0 || out === "") return null;
    return out;
  } catch {
    return null;
  }
}

// File/directory picker; null on cancel.
export async function gumFile(
  base: string,
  directory = false,
): Promise<string | null> {
  try {
    const argv = ["gum", "file", ...(directory ? ["--directory"] : []), base];
    const proc = Bun.spawn(argv, {
      stdout: "pipe",
      stderr: "inherit",
      stdin: "inherit",
    });
    const code = await proc.exited;
    const out = (await new Response(proc.stdout).text()).trim();
    if (code !== 0 || out === "") return null;
    return out;
  } catch {
    return null;
  }
}

export async function gumStyle(message: string, seconds = 2): Promise<void> {
  await runArgv(["gum", "style", message]).catch(() => 0);
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

// Detached with a short delay so the floating menu window is gone before
// any region selection starts.
function detachDelayed(argv: string[]): void {
  try {
    const proc = Bun.spawn(
      ["sh", "-c", `sleep 0.2; exec "$@"`, "--", ...argv],
      { stdout: "ignore", stderr: "ignore", stdin: "ignore" },
    );
    proc.unref();
  } catch {
    // best-effort
  }
}

// fio arguments for one direction of the disk test: direct, incompressible
// sequential I/O with 4 jobs, 8 seconds, in a scratch directory.
export function diskSpeedtestArgv(dir: string, rw: "read" | "write"): string[] {
  return [
    "fio",
    `--name=disk-${rw}`,
    `--directory=${dir}`,
    `--rw=${rw}`,
    "--bs=4M",
    "--size=256M",
    "--numjobs=4",
    "--ioengine=libaio",
    "--iodepth=8",
    "--direct=1",
    "--refill_buffers",
    "--runtime=8",
    "--time_based",
    "--group_reporting",
    "--eta-newline=1",
    "--unlink=1",
  ];
}

// Runs in the menu's own terminal, then waits so the result stays readable.
async function speedtestMenu(): Promise<void> {
  const sel = await gumChoose("Speed test", ["Network", "Disk", "Back"]);
  if (sel === "Network") {
    if (!commandAvailable("speedtest-go")) {
      await gumStyle("speedtest-go unavailable");
      return;
    }
    await runArgv(["speedtest-go"]);
  } else if (sel === "Disk") {
    if (!commandAvailable("fio")) {
      await gumStyle("fio unavailable");
      return;
    }
    const base = process.env.XDG_CACHE_HOME ?? `${process.env.HOME}/.cache`;
    const dir = `${base}/marchyo/disk-speedtest`;
    await runArgv(["mkdir", "-p", dir]);
    try {
      for (const rw of ["read", "write"] as const) {
        await runArgv(diskSpeedtestArgv(dir, rw));
      }
    } finally {
      await runArgv(["rm", "-rf", dir]);
    }
  } else {
    return;
  }
  await gumInput("", "Press Enter to go back");
}

// Written by marchyo.power.hibernation.enable.
const HIBERNATION_MARKER = "/etc/marchyo/hibernation";

export async function runPowerMenu(rt: Runtime): Promise<number> {
  const choice = await gumChoose("Power", [
    "Lock",
    "Lock + suspend",
    "Suspend",
    ...(existsSync(HIBERNATION_MARKER) ? ["Hibernate"] : []),
    "Log out",
    ...(shellInstalled() ? ["Restart shell"] : []),
    "Reboot",
    "Reboot to firmware",
    "Shutdown",
  ]);
  switch (choice) {
    case "Lock":
      return runLock(rt);
    case "Lock + suspend":
      return runLockSuspend(rt);
    case "Suspend":
      return runSuspend(rt);
    case "Hibernate":
      return runHibernate(rt);
    case "Log out":
      return runLogout(rt);
    case "Restart shell":
      return runShellReload(rt);
    case "Reboot":
      return runReboot(rt);
    case "Reboot to firmware":
      return runRebootFirmware(rt);
    case "Shutdown":
      return runShutdown(rt);
    default:
      return 0;
  }
}

async function styleMenu(rt: Runtime): Promise<void> {
  const manifest = await readThemeManifest();
  if (manifest.length === 0) {
    await gumStyle("No theme manifest — enable marchyo.desktop and rebuild.");
    return;
  }
  const current = themeAtPointer(manifest)?.name;
  const labels = manifest.map((t) =>
    t.name === current ? `${t.name} (current)` : t.name,
  );
  const sel = await gumChoose("Style", [...labels, "Back"]);
  if (sel === null || sel === "Back") return;
  const name = sel.replace(/ \(current\)$/, "");
  const code = await runThemeSet(rt, name, {});
  if (code === 0) {
    await gumStyle(`Theme switched to ${name} (runtime; --apply to persist)`, 1);
  } else {
    await gumStyle(`Could not switch to ${name}`);
  }
}

export const APPEARANCE_ITEMS = [
  "Theme",
  "Background",
  "Font",
  "Transparency",
  "Corners",
  "Animations",
  "Window gaps",
  "Fullscreen desktop",
  "Back",
] as const;

async function chooseFont(rt: Runtime): Promise<void> {
  const r = await captureArgv(["fc-list", ":mono", "family"]);
  const families = [
    ...new Set(
      r.stdout
        .split("\n")
        .map((l) => l.split(",")[0]!.trim())
        .filter((l) => l !== ""),
    ),
  ].sort();
  if (families.length === 0) {
    await gumStyle("No monospace fonts found");
    return;
  }
  const sel = await gumChoose("Font", [...families, "Back"]);
  if (sel === null || sel === "Back") return;
  await runFontSet(rt, sel, {});
}

async function chooseMode(
  header: string,
  modes: readonly string[],
  apply: (mode: string) => Promise<number>,
): Promise<void> {
  const sel = await gumChoose(header, [...modes, "Back"]);
  if (sel === null || sel === "Back") return;
  const code = await apply(sel);
  await gumStyle(code === 0 ? `${header}: ${sel}` : `Could not set ${sel}`, 1);
}

export async function appearanceMenu(rt: Runtime): Promise<void> {
  const sel = await gumChoose("Appearance", [...APPEARANCE_ITEMS]);
  switch (sel) {
    case "Theme":
      return styleMenu(rt);
    case "Background":
      await runBgNext(rt);
      return;
    case "Font":
      return chooseFont(rt);
    case "Transparency":
      return chooseMode("Transparency", TRANSPARENCY_MODES, (m) =>
        runThemeTransparency(rt, m, {}),
      );
    case "Corners":
      return chooseMode("Corners", CORNER_MODES, (m) => runThemeCorners(rt, m, {}));
    case "Animations":
      await runToggle(rt, "animations", undefined, {});
      return;
    case "Window gaps":
      await runToggle(rt, "gaps", undefined, {});
      return;
    case "Fullscreen desktop":
      await runToggle(rt, "fullscreen-desktop", undefined, {});
      return;
    default:
      return;
  }
}

async function setupMenu(rt: Runtime): Promise<"exit" | "loop"> {
  const sel = await gumChoose("Setup", [
    "Audio",
    "Wifi",
    "Bluetooth",
    "Monitors",
    "Power profile",
    "Back",
  ]);
  const tui: Record<string, string> = {
    Audio: "wiremix",
    Wifi: "nmtui",
    Bluetooth: "bluetui",
    Monitors: "hyprmon",
  };
  if (sel !== null && tui[sel]) {
    const tool = tui[sel]!;
    if (!commandAvailable(tool)) {
      await gumStyle(`${tool} unavailable`);
      return "loop";
    }
    // The TUI takes over the floating terminal; close the menu after it.
    await runArgv([tool]);
    return "exit";
  }
  if (sel === "Power profile") {
    const next = await cyclePowerProfile();
    await gumStyle(
      next === null ? "power-profiles-daemon unavailable" : `Power profile: ${next}`,
      1,
    );
  }
  return "loop";
}

export type MenuOpts = {
  tui?: boolean;
  ipc?: (fn: string, ...args: string[]) => Promise<string>;
};

// Opens the shell's command menu at a dotted route; the gum TUI when the
// shell is missing, not answering, or --tui is set.
export async function runMenu(
  rt: Runtime,
  route?: string,
  opts: MenuOpts = {},
): Promise<number> {
  const id = normalizeRoute(route);
  if (opts.tui !== true) {
    try {
      const reply = await (opts.ipc ?? shellIpc)("openMenu", id);
      if (reply !== "") process.stdout.write(reply + "\n");
      return 0;
    } catch (e) {
      if (!(e instanceof ShellIpcError)) throw e;
    }
  }
  return runMenuTui(rt, id);
}

export async function runMenuTui(rt: Runtime, route: string): Promise<number> {
  const target = tuiTarget(route);
  if (target === "power") return runPowerMenu(rt);
  if (target === "appearance") {
    if (!commandAvailable("gum")) {
      err(rt, tr("menu.gumNotFoundInPath"));
      return 1;
    }
    await appearanceMenu(rt);
    return 0;
  }
  if (!commandAvailable("gum")) {
    err(rt, tr("menu.gumNotFoundInPath"));
    return 1;
  }
  for (;;) {
    const main = await gumChoose("Marchyo", [
      "Trigger",
      "Setup",
      "Style",
      "Appearance",
      "System",
      "Learn",
    ]);
    switch (main) {
      case "Trigger": {
        const sel = await gumChoose("Trigger", [
          "Screenshot",
          "Screen record",
          "Color pick",
          "Share",
          "Speed test",
          "Back",
        ]);
        if (sel === "Screenshot") {
          detachDelayed(["marchyo", "capture", "screenshot"]);
          return 0;
        }
        if (sel === "Screen record") {
          detachDelayed(["marchyo", "capture", "record"]);
          return 0;
        }
        if (sel === "Color pick") {
          detachDelayed(["marchyo", "capture", "color"]);
          return 0;
        }
        // Interactive (file and device pickers), so it runs in this window.
        if (sel === "Share") return runShare(rt, []);
        if (sel === "Speed test") await speedtestMenu();
        break;
      }
      case "Setup": {
        if ((await setupMenu(rt)) === "exit") return 0;
        break;
      }
      case "Style":
        await styleMenu(rt);
        break;
      case "Appearance":
        await appearanceMenu(rt);
        break;
      case "System":
        return runPowerMenu(rt);
      case "Learn":
        return runKeybindings(rt);
      default:
        return 0;
    }
  }
}

export type MenuSelectOpts = {
  prompt?: string;
  multiple?: boolean;
  selected?: string[];
  width?: string;
  maxheight?: string;
  onChange?: string;
  changeKey?: string;
  tui?: boolean;
};

export type MenuDmenuDeps = MenuTransportDeps & {
  readStdin?: () => Promise<string>;
  gum?: (rows: MenuRow[], opts: MenuSelectOpts) => Promise<MenuRow[] | null>;
  gumLine?: (prompt: string) => Promise<string | null>;
};

function pixels(rt: Runtime, flag: string, raw: string | undefined): number | undefined | null {
  if (raw === undefined) return undefined;
  const n = Number(raw);
  if (Number.isInteger(n) && n > 0) return n;
  usageError(rt, tr("menu.invalidPixels", flag, raw));
  return null;
}

function argvList(rt: Runtime, raw: string | undefined): string[] | undefined | null {
  if (raw === undefined) return undefined;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (Array.isArray(parsed) && parsed.every((v) => typeof v === "string")) return parsed;
  } catch {
    // reported below
  }
  usageError(rt, tr("menu.invalidOnChange"));
  return null;
}

// Exit 0 with the value printed, 1 on cancel, 2 when the shell is unreachable.
function finish(rt: Runtime, outcome: MenuOutcome, multiple: boolean, need: string): number {
  if (outcome.kind === "chosen") {
    process.stdout.write(formatChoice(outcome.text, multiple) + "\n");
    return 0;
  }
  if (outcome.kind === "cancelled") return 1;
  err(rt, tr("menu.shellNotReachable", need, outcome.reason));
  return 2;
}

async function gumSelect(rows: MenuRow[], opts: MenuSelectOpts): Promise<MenuRow[] | null> {
  const argv = gumChooseArgv(opts.prompt, rows, opts.multiple === true, opts.selected ?? []);
  try {
    const proc = Bun.spawn(argv, { stdout: "pipe", stderr: "inherit", stdin: "inherit" });
    const code = await proc.exited;
    const out = await new Response(proc.stdout).text();
    if (code !== 0) return null;
    const lines = out.split("\n").filter((l) => l !== "");
    const picked = lines.flatMap((l) => rows.filter((r) => gumDisplay(r) === l).slice(0, 1));
    return picked.length === 0 ? null : picked;
  } catch {
    return null;
  }
}

export async function runMenuSelect(
  rt: Runtime,
  opts: MenuSelectOpts,
  deps: MenuDmenuDeps = {},
): Promise<number> {
  const width = pixels(rt, "--width", opts.width);
  const maxHeight = pixels(rt, "--maxheight", opts.maxheight);
  const onChange = argvList(rt, opts.onChange);
  if (width === null || maxHeight === null || onChange === null) return 2;
  const rows = parseRows(await (deps.readStdin ?? (() => Bun.stdin.text()))());
  if (rows.length === 0) {
    err(rt, tr("menu.noRows"));
    return 1;
  }
  const multiple = opts.multiple === true;
  const request = buildMenuRequest("select", {
    ...(opts.prompt !== undefined ? { prompt: opts.prompt } : {}),
    rows,
    multiple,
    ...(opts.selected !== undefined ? { selected: opts.selected } : {}),
    ...(width !== undefined ? { width } : {}),
    ...(maxHeight !== undefined ? { maxHeight } : {}),
    ...(onChange !== undefined ? { onChange } : {}),
    ...(opts.changeKey !== undefined ? { changeKey: opts.changeKey } : {}),
  });
  const outcome = await requestMenu(request, deps);
  if (outcome.kind === "unreachable" && opts.tui === true) {
    const picked = await (deps.gum ?? gumSelect)(rows, opts);
    if (picked === null) return 1;
    const values = picked.map(rowValue);
    process.stdout.write(
      (multiple ? JSON.stringify(values) : values[0]!) + "\n",
    );
    return 0;
  }
  return finish(rt, outcome, multiple, "select");
}

export async function runMenuInput(
  rt: Runtime,
  opts: { prompt?: string; width?: string; tui?: boolean },
  deps: MenuDmenuDeps = {},
): Promise<number> {
  const width = pixels(rt, "--width", opts.width);
  if (width === null) return 2;
  const request = buildMenuRequest("input", {
    ...(opts.prompt !== undefined ? { prompt: opts.prompt } : {}),
    ...(width !== undefined ? { width } : {}),
  });
  const outcome = await requestMenu(request, deps);
  if (outcome.kind === "unreachable" && opts.tui === true) {
    const line = await (deps.gumLine ?? ((p) => gumInput(p, "")))(opts.prompt ?? "> ");
    if (line === null) return 1;
    process.stdout.write(line + "\n");
    return 0;
  }
  return finish(rt, outcome, false, "input");
}

// Modifier bitmask to readable names.
function decodeMods(modmask: number): string {
  const mods: string[] = [];
  if (modmask & 64) mods.push("SUPER");
  if (modmask & 4) mods.push("CTRL");
  if (modmask & 8) mods.push("ALT");
  if (modmask & 1) mods.push("SHIFT");
  return mods.join("+");
}

type Bind = {
  description?: string;
  modmask: number;
  key?: string;
  keycode: number;
};

function bindKey(b: Bind): string {
  if (b.key && b.key !== "") return b.key;
  if (b.keycode >= 10 && b.keycode <= 18) return String(b.keycode - 9);
  if (b.keycode === 19) return "0";
  if (b.keycode !== 0) return `code:${b.keycode}`;
  return "mouse";
}

// One spelling for a chord: modifiers upper-case and sorted, key lower-case.
function chordId(mods: string[], key: string): string {
  return [...mods.map((m) => m.toUpperCase()).sort(), key.toLowerCase()].join("+");
}

function sheetChordId(combo: string): string {
  const parts = combo.split("+").map((p) => p.trim());
  return chordId(parts.slice(0, -1), parts[parts.length - 1] ?? "");
}

function bindChordId(b: Bind): string {
  const mods = decodeMods(b.modmask);
  return chordId(mods === "" ? [] : mods.split("+"), bindKey(b));
}

export function formatBindRows(binds: Bind[]): string[] {
  const rows = new Set<string>();
  for (const b of binds) {
    if (!b.description || b.description === "") continue;
    const mods = decodeMods(b.modmask);
    const key = bindKey(b);
    const combo = mods === "" ? key : `${mods}+${key}`;
    rows.add(`${combo.padEnd(24)}  ${b.description}`);
  }
  return [...rows].sort();
}

// One row of the cheat sheet the Home Manager module writes from the bind
// table (lib/keybinds.nix).
export type SheetEntry = { combo: string; description: string; group: string };

export function keybindingsSheetPath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_CONFIG_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".config");
  return join(base, "marchyo", "keybindings.json");
}

// The table rows in table order, then the described binds the table does
// not list (added downstream) as "Other". A bind matches a row when both
// its chord and its description do.
export function formatSheetRows(entries: SheetEntry[], binds: Bind[] = []): string[] {
  const known = new Set(entries.map((e) => `${sheetChordId(e.combo)} ${e.description}`));
  const rows = entries.map(
    (e) => `${e.group.padEnd(14)}  ${e.combo.padEnd(30)}  ${e.description}`,
  );
  const extra = binds.filter(
    (b) => b.description && !known.has(`${bindChordId(b)} ${b.description}`),
  );
  for (const row of formatBindRows(extra)) rows.push(`${"Other".padEnd(14)}  ${row}`);
  return rows;
}

function readSheet(): SheetEntry[] | null {
  try {
    return JSON.parse(readFileSync(keybindingsSheetPath(), "utf8")) as SheetEntry[];
  } catch {
    return null;
  }
}

async function hyprBinds(): Promise<Bind[] | null> {
  const r = await captureArgv(["hyprctl", "binds", "-j"]);
  if (r.code !== 0) return null;
  try {
    return JSON.parse(r.stdout) as Bind[];
  } catch {
    return null;
  }
}

export async function runKeybindings(rt: Runtime): Promise<number> {
  const sheet = readSheet();
  const binds = await hyprBinds();
  let rows: string[];
  if (sheet) {
    rows = formatSheetRows(sheet, binds ?? []);
  } else if (binds) {
    rows = formatBindRows(binds);
  } else {
    err(rt, tr("menu.hyprctlBindsFailedNotInside"));
    return 1;
  }
  if (rows.length === 0) {
    info(rt, tr("menu.noDescribedKeybindingsFound"));
    return 1;
  }
  if (!commandAvailable("fzf")) {
    // Non-interactive fallback: plain table on stdout.
    process.stdout.write(rows.join("\n") + "\n");
    return 0;
  }
  try {
    const proc = Bun.spawn(
      [
        "fzf",
        "--reverse",
        "--no-sort",
        "--cycle",
        "--prompt",
        "keybindings> ",
        "--header",
        "Hyprland keybindings — type to filter, Esc to close",
      ],
      { stdin: "pipe", stdout: "inherit", stderr: "inherit" },
    );
    proc.stdin.write(rows.join("\n") + "\n");
    await proc.stdin.end();
    await proc.exited;
    return 0;
  } catch {
    process.stdout.write(rows.join("\n") + "\n");
    return 0;
  }
}
