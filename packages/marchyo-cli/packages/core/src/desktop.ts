// Argv builders for the desktop actuators the runtime-first change model
// drives (hyprctl / makoctl / systemctl --user / notify-send / awww).
// Pure builders keep the exact command strings unit-testable; commands run
// them through system.ts:runArgv (or an injected exec in tests).
//
// The reload vocabulary deliberately mirrors modules/home/theme-runtime.nix:
//  - hyprland: `hyprctl eval` of an `hl.config({...})` table — the keyword
//    form is a no-op under non-legacy (Lua) parsers (exit 0, no effect) and
//    `hyprctl reload` re-reads the build-time config, so never use either
//    for live restyling
//  - waybar: full `systemctl --user try-restart` — SIGUSR2 spawns duplicates
//  - mako: `makoctl reload`

// hyprctl only works inside a live Hyprland session.
export function hyprlandAvailable(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  const sig = env.HYPRLAND_INSTANCE_SIGNATURE;
  return typeof sig === "string" && sig !== "";
}

// `hyprctl keyword` argv — still used by the hyprlang holdout sites
// (toggles/launch), which run on hosts the Lua parser hasn't reached.
export function hyprctlKeywordArgv(keyword: string, value: string): string[] {
  return ["hyprctl", "keyword", keyword, value];
}

// `hyprctl eval` argv — the only runtime option-mutation path that works
// under Hyprland's Lua (non-legacy) parser: `hyprctl keyword` prints
// "keyword can't work with non-legacy parsers. Use eval." and exits 0.
export function hyprctlEvalArgv(code: string): string[] {
  return ["hyprctl", "eval", code];
}

// Double-quoted Lua string literal. Hyprland's Lua config evaluates
// `hyprctl dispatch` arguments as `hl.dsp.*` expressions, so interpolated
// values must be escaped to stay a single string.
export function luaString(s: string): string {
  let out = '"';
  for (const ch of s) {
    const code = ch.codePointAt(0) ?? 0;
    if (ch === "\\") out += "\\\\";
    else if (ch === '"') out += '\\"';
    else if (code < 0x20 || code === 0x7f) {
      out += `\\${String(code).padStart(3, "0")}`;
    } else out += ch;
  }
  return `${out}"`;
}

// `dispatcher` is a Lua expression such as `hl.dsp.exit()`.
export function hyprctlDispatchArgv(dispatcher: string): string[] {
  return ["hyprctl", "dispatch", dispatcher];
}

export function hyprctlGetOptionArgv(option: string): string[] {
  return ["hyprctl", "getoption", "-j", option];
}

export function makoctlArgv(...args: string[]): string[] {
  return ["makoctl", ...args];
}

export function systemctlUserArgv(action: string, unit: string): string[] {
  return ["systemctl", "--user", action, unit];
}

// Low-urgency marchyo-branded notification (theme-runtime.nix's
// `notify-send -u low -a marchyo` convention).
export function notifySendArgv(
  summary: string,
  body?: string,
  opts: { urgency?: "low" | "normal" | "critical"; app?: string } = {},
): string[] {
  const argv = [
    "notify-send",
    "-u",
    opts.urgency ?? "low",
    "-a",
    opts.app ?? "marchyo",
    summary,
  ];
  if (body !== undefined) argv.push(body);
  return argv;
}

export function awwwImgArgv(image: string): string[] {
  return ["awww", "img", image, "--transition-type", "none"];
}

// setvtrgb(8) applies a 16-colour palette table to the kernel virtual consoles.
// Best-effort from a GUI session (no controlling VT there); see the caller in
// theme.ts. `table` is a setvtrgb file path (three comma-separated RGB lines).
export function setvtrgbArgv(table: string): string[] {
  return ["setvtrgb", table];
}

// Runtime theming owns this projection of the effective theme selection.
export const COLOR_SCHEME_KEY = "/org/gnome/desktop/interface/color-scheme";

// `dconf write <key> <gvariant>` — libadwaita/GTK4 apps watch this key over
// D-Bus and restyle live; GTK3 apps pick the relinked gtk.css up on next
// launch instead.
export function dconfWriteArgv(key: string, gvariant: string): string[] {
  return ["dconf", "write", key, gvariant];
}

// GVariant string for the color-scheme: the value is a string, so the
// quotes are part of the argument itself.
export function colorSchemeGvariant(variant: "dark" | "light"): string {
  return variant === "dark" ? "'prefer-dark'" : "'prefer-light'";
}

export const FONT_NAME_KEY = "/org/gnome/desktop/interface/font-name";
export const ICON_THEME_KEY = "/org/gnome/desktop/interface/icon-theme";

export function dconfReadArgv(key: string): string[] {
  return ["dconf", "read", key];
}

export function dconfResetArgv(key: string): string[] {
  return ["dconf", "reset", key];
}

// A GVariant string literal: single-quoted, backslash and quote escaped.
export function gvariantString(value: string): string {
  return `'${value.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;
}

// Split a GTK font description ("Inter 11", "Noto Sans Bold 10.5") into the
// family and the trailing size. A description without a size keeps size null.
export function splitFontName(name: string): { family: string; size: string | null } {
  const m = name.trim().match(/^(.*\S)\s+(\d+(?:\.\d+)?)$/);
  return m ? { family: m[1]!, size: m[2]! } : { family: name.trim(), size: null };
}

// `dconf read` prints a GVariant string ('Inter 11'); empty when unset.
export function parseGvariantString(out: string): string | null {
  const m = out.trim().match(/^'(.*)'$/s);
  if (!m) return null;
  const v = m[1]!.replace(/\\(['\\])/g, "$1");
  return v === "" ? null : v;
}
