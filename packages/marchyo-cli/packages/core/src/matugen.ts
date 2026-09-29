import { z } from "zod";
import { homedir } from "node:os";
import { join } from "node:path";

// Wallpaper-derived theming via matugen.
//
// `matugen image <img> --json hex` emits a `base16` block: base00..base0F,
// each carrying per-mode `{ dark|light|default: { color } }`. We treat that
// block exactly like a tinted-schemes base16 scheme and run it through the
// same token->slot / ANSI mapping modules/home/theme-runtime.nix uses at build
// time, so a wallpaper-generated theme recolors the same runtime surfaces a
// catalog scheme does (the shell's colors.json, ghostty, Hyprland borders, and
// the wallpaper). Build-time Stylix surfaces (Qt/bat/fzf/starship) keep the
// declarative theme until the next rebuild — the same limitation every runtime
// theme switch has.

export type Variant = "dark" | "light";
export type Base16 = Record<string, string>; // base00..base0F -> "#rrggbb"

const ColorNode = z.object({ color: z.string() });
const Base16Node = z.object({
  dark: ColorNode.optional(),
  light: ColorNode.optional(),
  default: ColorNode,
});
const MatugenJson = z.object({
  is_dark_mode: z.boolean().optional(),
  base16: z.record(z.string(), Base16Node),
});

export const BASE16_SLOTS = [
  "base00",
  "base01",
  "base02",
  "base03",
  "base04",
  "base05",
  "base06",
  "base07",
  "base08",
  "base09",
  "base0A",
  "base0B",
  "base0C",
  "base0D",
  "base0E",
  "base0F",
] as const;

// `--source-color-index 0` picks the most dominant extracted colour and (per
// matugen's own docs) suppresses the interactive source-colour prompt, so the
// command runs in a headless session (no TTY) without hanging.
export function matugenArgv(image: string): string[] {
  return [
    "matugen",
    "image",
    image,
    "--json",
    "hex",
    "--source-color-index",
    "0",
  ];
}

// matugen's own dark/light detection for the image (used when the caller does
// not force a polarity).
export function detectVariant(raw: string): Variant {
  const parsed = MatugenJson.parse(JSON.parse(raw));
  return parsed.is_dark_mode === false ? "light" : "dark";
}

export function parseMatugenBase16(raw: string, variant: Variant): Base16 {
  const parsed = MatugenJson.parse(JSON.parse(raw));
  const out: Base16 = {};
  for (const slot of BASE16_SLOTS) {
    const node = parsed.base16[slot];
    if (!node) throw new Error(`matugen output missing ${slot}`);
    const picked = (variant === "light" ? node.light : node.dark) ?? node.default;
    out[slot] = picked.color.toLowerCase();
  }
  return out;
}

// colors.json key (camelCase) -> base16 slot. Mirrors the tokenSlots table in
// modules/home/theme-runtime.nix (kebab there, camelCase here to match the
// colors.json keys the shell reads). Keys absent from this map keep their
// current hex — the same identity fallback the Nix schemeHexForToken uses.
export const TOKEN_SLOTS: Record<string, string> = {
  bg: "base00",
  bgSubtle: "base01",
  surface: "base02",
  surfaceRaised: "base07",
  textFaint: "base03",
  textMuted: "base04",
  text: "base05",
  textHeading: "base06",
  statusErr: "base08",
  accent: "base09",
  statusWarn: "base0A",
  synString: "base0B",
  synType: "base0C",
  statusInfo: "base0D",
  synKeyword: "base0E",
  brand: "base0F",
  border: "base03",
  borderStrong: "base04",
  accentHover: "base09",
  accentSubtle: "base01",
  statusOk: "base0B",
  synComment: "base03",
};

export const ColorsJson = z.object({
  name: z.string(),
  variant: z.enum(["dark", "light"]),
  colors: z.record(z.string(), z.string()),
});
export type ColorsJson = z.infer<typeof ColorsJson>;

// Recolour an existing colors.json from a base16 palette: each key mapped in
// TOKEN_SLOTS takes the matugen slot; unmapped keys keep their current hex.
// Iterating the *current* colors.json (rather than a hardcoded token list)
// keeps the key set in lockstep with what the shell actually reads.
export function recolorShellColors(
  current: ColorsJson,
  base16: Base16,
  variant: Variant,
  name: string,
): ColorsJson {
  const colors: Record<string, string> = {};
  for (const [key, hex] of Object.entries(current.colors)) {
    const slot = TOKEN_SLOTS[key];
    colors[key] = slot ? base16[slot]! : hex;
  }
  return { name, variant, colors };
}

const noHash = (h: string): string => (h.startsWith("#") ? h.slice(1) : h);

// The three Hyprland colour keywords theme-runtime.nix's schemeHyprlandKeywords
// emits, in the same `section:subkey value` line form activateThemeDir parses.
export function hyprlandConfFromBase16(b: Base16): string {
  return (
    [
      `misc:background_color rgb(${noHash(b.base00!)})`,
      `general:col.active_border rgba(${noHash(b.base09!)}ff)`,
      `general:col.inactive_border rgba(${noHash(b.base04!)}ff)`,
    ].join("\n") + "\n"
  );
}

// Ghostty terminal colours + the 16-entry ANSI palette, matching
// theme-runtime.nix's schemeGhosttyConf (base16's standard ANSI mapping).
export function ghosttyConfFromBase16(b: Base16): string {
  const ansi = [
    b.base00,
    b.base08,
    b.base0B,
    b.base0A,
    b.base0D,
    b.base0E,
    b.base0C,
    b.base05,
    b.base03,
    b.base08,
    b.base0B,
    b.base0A,
    b.base0D,
    b.base0E,
    b.base0C,
    b.base07,
  ];
  const head =
    [
      `background = ${b.base00}`,
      `foreground = ${b.base05}`,
      `cursor-color = ${b.base05}`,
      `selection-background = ${b.base02}`,
      `selection-foreground = ${b.base05}`,
    ].join("\n") + "\n";
  return head + ansi.map((c, i) => `palette = ${i}=${c}`).join("\n") + "\n";
}

// Writable runtime location for the generated theme dir (the manifest themes
// are read-only /nix/store dirs, so the generated one lives in state).
export function generatedThemeDirPath(
  env: NodeJS.ProcessEnv = process.env,
): string {
  const xdg = env.XDG_STATE_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".local", "state");
  return join(base, "marchyo", "generated-theme");
}
