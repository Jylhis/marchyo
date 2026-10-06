import { z } from "zod";
import { homedir } from "node:os";
import { join } from "node:path";

// Wallpaper-derived theming via matugen.
//
// `matugen image <img> --json hex` emits a `base16` block: base00..base0F,
// each carrying per-mode `{ dark|light|default: { color } }`. We treat that
// block exactly like a tinted-schemes base16 scheme and run it through the
// token->slot table each theme dir ships in palette.json, with TS ports of the
// lib/theme-generators.nix generators, so a wallpaper-generated theme carries
// the same asset set a catalog scheme's dir does. Qt follows the runtime GTK
// swap; only plymouth keeps the declarative theme until the next rebuild, the
// same limitation every runtime theme switch has.

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

// palette.json, shipped in every theme dir by modules/home/theme-runtime.nix:
// the full kebab-case token -> hex map (syn-* included) and the token ->
// base16 slot table (lib/theme-generators.nix's tokenSlots).
export const ThemePalette = z.object({
  tokens: z.record(z.string(), z.string()),
  tokenSlots: z.record(z.string(), z.string()),
});
export type ThemePalette = z.infer<typeof ThemePalette>;

export type TokenResolver = (token: string) => string;

// Token -> hex for a base16 palette: the slot when tokenSlots maps the token,
// else the palette's own (build-variant) hex. Same rule as the Nix
// slotResolver.
export function tokenResolver(
  palette: ThemePalette,
  base16: Base16,
): TokenResolver {
  return (token) => {
    const slot = palette.tokenSlots[token];
    const hex = slot ? base16[slot] : palette.tokens[token];
    if (hex === undefined) throw new Error(`no colour for theme token ${token}`);
    return hex;
  };
}

// The generated theme dir's own palette.json: every token resolved.
export function resolvedPalette(
  palette: ThemePalette,
  resolve: TokenResolver,
): ThemePalette {
  const tokens: Record<string, string> = {};
  for (const name of Object.keys(palette.tokens).sort()) {
    tokens[name] = resolve(name);
  }
  return { tokens, tokenSlots: palette.tokenSlots };
}

// kebab-case -> camelCase, matching lib/camel-case.nix (colors.json keys).
export function toCamel(name: string): string {
  return name
    .split("-")
    .map((w, i) => (i === 0 ? w : w.charAt(0).toUpperCase() + w.slice(1)))
    .join("");
}

export const ColorsJson = z.object({
  name: z.string(),
  variant: z.enum(["dark", "light"]),
  colors: z.record(z.string(), z.string()),
});
export type ColorsJson = z.infer<typeof ColorsJson>;

// Recolour a colors.json (camelCase keys) through the token resolver. Keys
// that name no palette token keep their current hex. Iterating the given
// colors.json keeps the key set in lockstep with what the shell reads.
export function recolorShellColors(
  current: ColorsJson,
  palette: ThemePalette,
  resolve: TokenResolver,
  variant: Variant,
  name: string,
): ColorsJson {
  const byCamel = new Map(
    Object.keys(palette.tokens).map((t) => [toCamel(t), t] as const),
  );
  const colors: Record<string, string> = {};
  for (const [key, hex] of Object.entries(current.colors)) {
    const token = byCamel.get(key);
    colors[key] = token ? resolve(token) : hex;
  }
  return { name, variant, colors };
}

const noHash = (h: string): string => (h.startsWith("#") ? h.slice(1) : h);
const rgba = (h: string, a: string): string => `rgba(${noHash(h)}${a})`;

function rgbTriple(h: string): number[] {
  const x = noHash(h);
  return [0, 2, 4].map((o) => parseInt(x.slice(o, o + 2), 16));
}

// GTK's shade_color literal (lib/theme-generators.nix shadeRgba).
export function shadeRgba(h: string): string {
  return `rgba(${rgbTriple(h).join(", ")}, 0.08)`;
}

// The three Hyprland colour keywords (lib/theme-generators.nix
// hyprlandKeywordsFor), in the `section:subkey value` line form
// activateThemeDir parses.
export function hyprlandConfFor(resolve: TokenResolver): string {
  return (
    [
      `misc:background_color rgb(${noHash(resolve("bg"))})`,
      `general:col.active_border ${rgba(resolve("accent"), "ff")}`,
      `general:col.inactive_border ${rgba(resolve("border-strong"), "ff")}`,
    ].join("\n") + "\n"
  );
}

// Ghostty terminal colours + the 16-entry ANSI palette (lib/theme-generators.nix
// ghosttyConfFromSlots, base16's standard ANSI mapping).
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

// fzf `--color` string (lib/theme-generators.nix fzfOptsText); `green` is the
// ANSI green the `marker` role uses.
export function fzfOptsFor(resolve: TokenResolver, green: string): string {
  return (
    "--color=" +
    [
      `fg:${resolve("text")}`,
      `bg:${resolve("bg")}`,
      `hl:${resolve("accent")}`,
      `fg+:${resolve("text-heading")}`,
      `bg+:${resolve("accent-subtle")}`,
      `hl+:${resolve("accent-hover")}`,
      `info:${resolve("text-muted")}`,
      `marker:${green}`,
      `prompt:${resolve("accent")}`,
      `spinner:${resolve("accent")}`,
      `pointer:${resolve("accent")}`,
      `header:${resolve("text-muted")}`,
      `border:${resolve("border")}`,
      `separator:${resolve("border")}`,
      `gutter:${resolve("bg")}`,
    ].join(",") +
    "\n"
  );
}

// hyprlock colour include (lib/theme-generators.nix hyprlockVarsFor): the
// hyprlang `$var`s modules/home/hyprlock.nix sources first.
export function hyprlockColorsFor(resolve: TokenResolver): string {
  return (
    [
      `$bg = ${rgba(resolve("bg"), "ff")}`,
      `$text = ${rgba(resolve("text"), "ff")}`,
      `$borderStrong = ${rgba(resolve("border-strong"), "ff")}`,
      `$surface = ${rgba(resolve("surface"), "ff")}`,
      `$accent = ${rgba(resolve("accent"), "ff")}`,
      `$statusErr = ${rgba(resolve("status-err"), "ff")}`,
    ].join("\n") + "\n"
  );
}

// 16 console colours (lib/theme-generators.nix tty16FromSlots): the base16
// ANSI mapping with slots 0/7/15 set to bg/text/text-heading.
export function tty16FromBase16(b: Base16): string[] {
  return [
    b.base00!,
    b.base08!,
    b.base0B!,
    b.base0A!,
    b.base0D!,
    b.base0E!,
    b.base0C!,
    b.base05!,
    b.base03!,
    b.base08!,
    b.base0B!,
    b.base0A!,
    b.base0D!,
    b.base0E!,
    b.base0C!,
    b.base06!,
  ];
}

// setvtrgb(8) table (lib/console-table.nix): reds, greens, blues lines, each
// the 16 colours as 0-255 decimals.
export function consoleTable(hexes: string[]): string {
  const triples = hexes.map(rgbTriple);
  return (
    [0, 1, 2].map((c) => triples.map((t) => t[c]).join(",")).join("\n") + "\n"
  );
}

// bat/Sublime `.tmTheme` from base16 slots (lib/base16-tmtheme.nix), byte for
// byte so a generated theme renders like a catalog scheme.
export function tmThemeFromBase16(name: string, b: Base16): string {
  const scope = (scopeName: string, selector: string, color: string): string =>
    [
      "<dict>",
      `  <key>name</key><string>${scopeName}</string>`,
      `  <key>scope</key><string>${selector}</string>`,
      `  <key>settings</key><dict><key>foreground</key><string>${color}</string></dict>`,
      "</dict>",
    ].join("\n");
  const scopes = [
    scope("Comment", "comment, punctuation.definition.comment", b.base03!),
    scope("String", "string, constant.other.symbol", b.base0B!),
    scope("Number", "constant.numeric, constant.language", b.base09!),
    scope("Constant", "constant, support.constant", b.base09!),
    scope("Keyword", "keyword, storage.type, storage.modifier", b.base0E!),
    scope("Operator", "keyword.operator, punctuation", b.base05!),
    scope("Function", "entity.name.function, support.function", b.base0D!),
    scope(
      "Type",
      "entity.name.type, entity.name.class, support.type, support.class",
      b.base0A!,
    ),
    scope("Variable", "variable, variable.parameter", b.base08!),
    scope("Tag", "entity.name.tag", b.base08!),
    scope("Attribute", "entity.other.attribute-name", b.base09!),
    scope("Invalid", "invalid, invalid.illegal", b.base08!),
  ];
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    '<plist version="1.0">',
    "<dict>",
    "  <key>name</key>",
    `  <string>${name}</string>`,
    "  <key>settings</key>",
    "  <array>",
    "    <dict>",
    "      <key>settings</key>",
    "      <dict>",
    `        <key>background</key><string>${b.base00}</string>`,
    `        <key>foreground</key><string>${b.base05}</string>`,
    `        <key>caret</key><string>${b.base05}</string>`,
    `        <key>selection</key><string>${b.base02}</string>`,
    `        <key>lineHighlight</key><string>${b.base01}</string>`,
    `        <key>gutterForeground</key><string>${b.base03}</string>`,
    "      </dict>",
    "    </dict>",
    scopes.join("\n"),
    "  </array>",
    "</dict>",
    "</plist>",
    "",
  ].join("\n");
}

// Long-tail TUI surfaces themed from base16 slots alone
// (lib/theme-generators.nix k9sSkinFromSlots, lazygitThemeFromSlots,
// spotifyPlayerPaletteFromSlots, gduText), serialized byte for byte like the
// Nix `*Text` renderers.
type YamlValue = string | boolean | string[] | YamlMap;
type YamlMap = { [key: string]: YamlValue };

// Block-style YAML (lib/theme-generators.nix yamlText): keys sorted, strings
// JSON-quoted, string lists in flow style.
export function yamlText(map: YamlMap): string {
  const scalar = (v: string | boolean | string[]): string =>
    typeof v === "boolean"
      ? String(v)
      : Array.isArray(v)
        ? `[${v.map((x) => JSON.stringify(x)).join(", ")}]`
        : JSON.stringify(v);
  const lines = (indent: string, m: YamlMap): string[] =>
    Object.keys(m)
      .sort()
      .flatMap((k) => {
        const v = m[k]!;
        return typeof v === "object" && !Array.isArray(v)
          ? [`${indent}${k}:`, ...lines(`${indent}  `, v)]
          : [`${indent}${k}: ${scalar(v)}`];
      });
  return lines("", map)
    .map((l) => `${l}\n`)
    .join("");
}

export function k9sSkinFromBase16(b: Base16): YamlMap {
  return {
    k9s: {
      body: { fgColor: b.base05!, bgColor: "default", logoColor: b.base0C! },
      prompt: {
        fgColor: b.base05!,
        bgColor: "default",
        suggestColor: b.base02!,
      },
      info: { fgColor: b.base0B!, sectionColor: b.base05! },
      dialog: {
        fgColor: b.base05!,
        bgColor: b.base01!,
        buttonFgColor: b.base05!,
        buttonBgColor: b.base02!,
        buttonFocusFgColor: b.base00!,
        buttonFocusBgColor: b.base0B!,
        labelFgColor: b.base0A!,
        fieldFgColor: b.base05!,
      },
      frame: {
        border: { fgColor: b.base02!, focusColor: b.base01! },
        menu: {
          fgColor: b.base05!,
          keyColor: b.base0B!,
          numKeyColor: b.base0B!,
        },
        crumbs: {
          fgColor: b.base05!,
          bgColor: b.base01!,
          activeColor: b.base02!,
        },
        status: {
          newColor: b.base0C!,
          modifyColor: b.base09!,
          addColor: b.base0B!,
          errorColor: b.base08!,
          highlightcolor: b.base0A!,
          killColor: b.base03!,
          completedColor: b.base03!,
        },
        title: {
          fgColor: b.base05!,
          bgColor: b.base01!,
          highlightColor: b.base0A!,
          counterColor: b.base0C!,
          filterColor: b.base0B!,
        },
      },
      views: {
        charts: {
          bgColor: "default",
          defaultDialColors: [b.base0C!, b.base0D!],
          defaultChartColors: [b.base0C!, b.base0D!],
        },
        table: {
          fgColor: b.base05!,
          bgColor: "default",
          header: {
            fgColor: b.base05!,
            bgColor: "default",
            sorterColor: b.base08!,
          },
        },
        xray: {
          fgColor: b.base05!,
          bgColor: "default",
          cursorColor: b.base01!,
          graphicColor: b.base0C!,
          showIcons: false,
        },
        yaml: {
          keyColor: b.base08!,
          colonColor: b.base05!,
          valueColor: b.base0B!,
        },
        logs: {
          fgColor: b.base05!,
          bgColor: "default",
          indicator: {
            fgColor: b.base05!,
            bgColor: "default",
            toggleOnColor: b.base0B!,
            toggleOffColor: b.base04!,
          },
        },
        help: {
          fgColor: b.base05!,
          bgColor: "default",
          indicator: { fgColor: b.base0D! },
        },
      },
    },
  };
}

export function k9sSkinText(b: Base16): string {
  return yamlText(k9sSkinFromBase16(b));
}

// lazygit `gui.theme` overlay, merged over the main config via LG_CONFIG_FILE.
export function lazygitText(b: Base16): string {
  return yamlText({
    gui: {
      theme: {
        activeBorderColor: [b.base0D!, "bold"],
        inactiveBorderColor: [b.base03!],
        searchingActiveBorderColor: [b.base04!, "bold"],
        optionsTextColor: [b.base06!],
        selectedLineBgColor: [b.base03!],
        cherryPickedCommitBgColor: [b.base02!],
        cherryPickedCommitFgColor: [b.base03!],
        unstagedChangesColor: [b.base08!],
        defaultFgColor: [b.base05!],
      },
    },
  });
}

// spotify-player theme.toml with the one `jylhis` theme its app.toml selects.
export function spotifyPlayerThemeText(b: Base16): string {
  const palette: Record<string, string> = {
    background: b.base00!,
    foreground: b.base05!,
    black: b.base00!,
    red: b.base08!,
    green: b.base0B!,
    yellow: b.base0A!,
    blue: b.base0D!,
    magenta: b.base0E!,
    cyan: b.base0C!,
    white: b.base05!,
    bright_black: b.base03!,
    bright_red: b.base08!,
    bright_green: b.base0B!,
    bright_yellow: b.base0A!,
    bright_blue: b.base0D!,
    bright_magenta: b.base0E!,
    bright_cyan: b.base0C!,
    bright_white: b.base07!,
  };
  return (
    '[[themes]]\nname = "jylhis"\n\n[themes.palette]\n' +
    Object.keys(palette)
      .sort()
      .map((k) => `${k} = ${JSON.stringify(palette[k])}\n`)
      .join("")
  );
}

// gdu.yaml; the file carries only the theme.
export function gduText(b: Base16): string {
  return [
    "style:",
    "  selected-row:",
    `    text-color: "${b.base05}"`,
    `    background-color: "${b.base00}"`,
    "  result-row:",
    `    number-color: "${b.base06}"`,
    `    directory-color: "${b.base02}"`,
    "  footer:",
    `    text-color: "${b.base05}"`,
    `    background-color: "${b.base00}"`,
    `    number-color: "${b.base06}"`,
    "  header:",
    `    text-color: "${b.base05}"`,
    `    background-color: "${b.base00}"`,
    "",
  ].join("\n");
}

// Fill a build-variant surface template (theme dir `templates/`): each
// `{{token:<name>}}` becomes the resolved hex and `{{shade}}` the GTK shade of
// the resolved text colour. An unknown token name throws rather than shipping
// a placeholder.
export function fillTemplate(text: string, resolve: TokenResolver): string {
  return text
    .replace(/\{\{token:([a-z0-9-]+)\}\}/g, (_, name: string) => resolve(name))
    .replace(/\{\{shade\}\}/g, () => shadeRgba(resolve("text")));
}

// Point bat's config at `theme`: rewrite the `--theme=` line, keep the rest.
export function batConfigWithTheme(config: string, theme: string): string {
  return config.replace(/^--theme=.*$/m, `--theme=${theme}`);
}

// The bat theme name (tmTheme filename stem) `theme generate` writes.
export const GENERATED_BAT_THEME = "marchyo-generated";

// bat resolves its themes dir from the config dir (honouring BAT_CONFIG_DIR);
// `cache --build` compiles every tmTheme there into the theme cache.
export function batConfigDirArgv(): string[] {
  return ["bat", "--config-dir"];
}

export function batCacheBuildArgv(): string[] {
  return ["bat", "cache", "--build"];
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
