import {
  type Runtime,
  captureArgv,
  commandAvailable,
  err,
  info,
  readThemeManifest,
  runArgv,
  themeAtPointer,
  usageError,
} from "@marchyo/core";
import {
  cyclePowerProfile,
  runHibernate,
  runLock,
  runLogout,
  runReboot,
  runShutdown,
  runSuspend,
} from "./power.ts";
import { runCaptureColor, runCaptureRecord, runCaptureScreenshot } from "./capture.ts";
import { runThemeSet } from "./theme.ts";

// The gum-TUI menus (absorbed from marchyo-menu / marchyo-power-menu) and
// the fzf keybindings cheatsheet (absorbed from marchyo-keybindings). The
// presentation stays gum/fzf in a floating ghostty; every dispatched action
// is a marchyo command.

// gum renders its UI on the tty (stderr) and prints the selection to
// stdout — so pipe stdout only. A cancelled prompt exits non-zero.
export async function gumChoose(
  header: string,
  options: string[],
): Promise<string | null> {
  try {
    const proc = Bun.spawn(["gum", "choose", "--header", header, ...options], {
      stdout: "pipe",
      stderr: "inherit",
      stdin: "inherit",
    });
    const code = await proc.exited;
    const out = await new Response(proc.stdout).text();
    if (code !== 0) return null;
    const choice = out.trim();
    return choice === "" ? null : choice;
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
// any region selection starts (the old menu's `detach` helper).
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

export async function runPowerMenu(rt: Runtime): Promise<number> {
  const choice = await gumChoose("Power", [
    "Lock",
    "Suspend",
    "Hibernate",
    "Relaunch",
    "Reboot",
    "Shutdown",
  ]);
  switch (choice) {
    case "Lock":
      return runLock(rt);
    case "Suspend":
      return runSuspend(rt);
    case "Hibernate":
      return runHibernate(rt);
    case "Relaunch":
      return runLogout(rt);
    case "Reboot":
      return runReboot(rt);
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

export async function runMenu(rt: Runtime, submenu?: string): Promise<number> {
  if (submenu === "power") return runPowerMenu(rt);
  if (submenu !== undefined) {
    return usageError(rt, `unknown menu: "${submenu}"`, "marchyo menu [power]");
  }
  if (!commandAvailable("gum")) {
    err(rt, "gum not found in PATH (is marchyo.menus enabled?)");
    return 1;
  }
  for (;;) {
    const main = await gumChoose("Marchyo", [
      "Trigger",
      "Setup",
      "Style",
      "System",
      "Learn",
    ]);
    switch (main) {
      case "Trigger": {
        const sel = await gumChoose("Trigger", [
          "Screenshot",
          "Screen record",
          "Color pick",
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
        break;
      }
      case "Setup": {
        if ((await setupMenu(rt)) === "exit") return 0;
        break;
      }
      case "Style":
        await styleMenu(rt);
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

// Modifier bitmask → readable names (the jq decode from the absorbed
// marchyo-keybindings script).
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

export function formatBindRows(binds: Bind[]): string[] {
  const rows = new Set<string>();
  for (const b of binds) {
    if (!b.description || b.description === "") continue;
    const mods = decodeMods(b.modmask);
    let key: string;
    if (b.key && b.key !== "") key = b.key;
    else if (b.keycode >= 10 && b.keycode <= 18) key = String(b.keycode - 9);
    else if (b.keycode === 19) key = "0";
    else if (b.keycode !== 0) key = `code:${b.keycode}`;
    else key = "mouse";
    const combo = mods === "" ? key : `${mods}+${key}`;
    rows.add(`${combo.padEnd(24)}  ${b.description}`);
  }
  return [...rows].sort();
}

export async function runKeybindings(rt: Runtime): Promise<number> {
  const r = await captureArgv(["hyprctl", "binds", "-j"]);
  if (r.code !== 0) {
    err(rt, "hyprctl binds failed (not inside a Hyprland session?)");
    return 1;
  }
  let rows: string[];
  try {
    rows = formatBindRows(JSON.parse(r.stdout) as Bind[]);
  } catch {
    err(rt, "could not parse hyprctl binds output");
    return 1;
  }
  if (rows.length === 0) {
    info(rt, "no described keybindings found");
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
