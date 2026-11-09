import { type Base16, type Variant, tty16FromBase16 } from "./matugen.ts";

// Application surfaces (lib/theme-generators.nix appSurfaceTexts), from base16
// slots. JSON goes through sortedJson to match builtins.toJSON byte for byte.
type Json = string | number | boolean | Json[] | { [key: string]: Json };

export function sortedJson(v: Json): string {
  const enc = (x: Json): string =>
    Array.isArray(x)
      ? `[${x.map(enc).join(",")}]`
      : typeof x === "object"
        ? `{${Object.keys(x)
            .sort()
            .map((k) => `${JSON.stringify(k)}:${enc(x[k]!)}`)
            .join(",")}}`
        : JSON.stringify(x);
  return `${enc(v)}\n`;
}

const VSCODE_ANSI_NAMES = [
  "Black",
  "Red",
  "Green",
  "Yellow",
  "Blue",
  "Magenta",
  "Cyan",
  "White",
  "BrightBlack",
  "BrightRed",
  "BrightGreen",
  "BrightYellow",
  "BrightBlue",
  "BrightMagenta",
  "BrightCyan",
  "BrightWhite",
];

export function vscodeThemeText(variant: Variant, b: Base16): string {
  const s = b as Record<string, string>;
  const token = (scope: string[], foreground: string): Json => ({
    scope,
    settings: { foreground },
  });
  const terminal: Record<string, string> = {};
  tty16FromBase16(b).forEach((c, i) => {
    terminal[`terminal.ansi${VSCODE_ANSI_NAMES[i]}`] = c;
  });
  return sortedJson({
    name: "Marchyo",
    type: variant,
    semanticHighlighting: true,
    colors: {
      foreground: s.base05!,
      focusBorder: s.base0D!,
      descriptionForeground: s.base04!,
      errorForeground: s.base08!,
      "selection.background": s.base02!,
      "editor.background": s.base00!,
      "editor.foreground": s.base05!,
      "editor.selectionBackground": s.base02!,
      "editor.lineHighlightBackground": s.base01!,
      "editor.findMatchBackground": s.base02!,
      "editorCursor.foreground": s.base05!,
      "editorLineNumber.foreground": s.base03!,
      "editorLineNumber.activeForeground": s.base05!,
      "editorIndentGuide.background1": s.base01!,
      "editorWhitespace.foreground": s.base03!,
      "editorGroupHeader.tabsBackground": s.base01!,
      "editorWidget.background": s.base01!,
      "activityBar.background": s.base01!,
      "activityBar.foreground": s.base05!,
      "activityBar.inactiveForeground": s.base04!,
      "activityBarBadge.background": s.base0D!,
      "activityBarBadge.foreground": s.base00!,
      "sideBar.background": s.base01!,
      "sideBar.foreground": s.base05!,
      "sideBarSectionHeader.background": s.base01!,
      "statusBar.background": s.base01!,
      "statusBar.foreground": s.base05!,
      "statusBar.noFolderBackground": s.base01!,
      "titleBar.activeBackground": s.base01!,
      "titleBar.activeForeground": s.base05!,
      "titleBar.inactiveBackground": s.base00!,
      "tab.activeBackground": s.base00!,
      "tab.activeForeground": s.base05!,
      "tab.inactiveBackground": s.base01!,
      "tab.inactiveForeground": s.base04!,
      "tab.border": s.base00!,
      "panel.background": s.base00!,
      "panel.border": s.base03!,
      "panelTitle.activeForeground": s.base05!,
      "input.background": s.base01!,
      "input.foreground": s.base05!,
      "input.border": s.base03!,
      "button.background": s.base0D!,
      "button.foreground": s.base00!,
      "dropdown.background": s.base01!,
      "dropdown.foreground": s.base05!,
      "list.activeSelectionBackground": s.base02!,
      "list.activeSelectionForeground": s.base05!,
      "list.hoverBackground": s.base01!,
      "list.highlightForeground": s.base0D!,
      "textLink.foreground": s.base0D!,
      "badge.background": s.base0D!,
      "badge.foreground": s.base00!,
      "terminal.background": s.base00!,
      "terminal.foreground": s.base05!,
      "terminal.selectionBackground": s.base02!,
      "terminalCursor.foreground": s.base05!,
      ...terminal,
    },
    tokenColors: [
      token(["comment", "punctuation.definition.comment"], s.base03!),
      token(["string", "constant.other.symbol"], s.base0B!),
      token(["constant.numeric", "constant.language", "constant"], s.base09!),
      token(["keyword", "storage.type", "storage.modifier"], s.base0E!),
      token(["keyword.operator", "punctuation"], s.base05!),
      token(["entity.name.function", "support.function"], s.base0D!),
      token(
        [
          "entity.name.type",
          "entity.name.class",
          "support.type",
          "support.class",
        ],
        s.base0A!,
      ),
      token(
        ["variable", "variable.parameter", "entity.name.tag", "invalid"],
        s.base08!,
      ),
      token(["entity.other.attribute-name"], s.base09!),
    ],
  });
}

export function obsidianCssText(b: Base16): string {
  const vars: [string, string][] = [
    ["background-primary", b.base00!],
    ["background-primary-alt", b.base01!],
    ["background-secondary", b.base01!],
    ["background-secondary-alt", b.base00!],
    ["background-modifier-border", b.base03!],
    ["text-normal", b.base05!],
    ["text-muted", b.base04!],
    ["text-faint", b.base03!],
    ["text-selection", b.base02!],
    ["text-link", b.base0D!],
    ["text-accent", b.base0D!],
    ["text-accent-hover", b.base0D!],
    ["interactive-accent", b.base0D!],
    ["interactive-accent-hover", b.base0D!],
    ["text-error", b.base08!],
    ["text-success", b.base0B!],
    ["code-normal", b.base0C!],
    ["tag-color", b.base0C!],
    ["text-title-h1", b.base08!],
    ["text-title-h2", b.base0B!],
    ["text-title-h3", b.base0A!],
    ["text-title-h4", b.base0D!],
    ["text-title-h5", b.base0E!],
    ["text-title-h6", b.base0E!],
    ["graph-line", b.base03!],
    ["graph-node", b.base0D!],
  ];
  return (
    ".theme-dark,\n.theme-light {\n" +
    vars.map(([k, v]) => `  --${k}: ${v};\n`).join("") +
    "}\n"
  );
}

export function tmuxConfText(b: Base16): string {
  return (
    [
      `set -g status-style "fg=${b.base05},bg=${b.base01}"`,
      `set -g message-style "fg=${b.base05},bg=${b.base02}"`,
      `set -g message-command-style "fg=${b.base05},bg=${b.base02}"`,
      `set -g mode-style "fg=${b.base05},bg=${b.base02}"`,
      `set -g pane-border-style "fg=${b.base03}"`,
      `set -g pane-active-border-style "fg=${b.base0D}"`,
      `set -g window-style "fg=${b.base05},bg=${b.base00}"`,
      `set -g window-active-style "fg=${b.base05},bg=${b.base00}"`,
      `set -g window-status-style "fg=${b.base04},bg=${b.base01}"`,
      `set -g window-status-current-style "fg=${b.base00},bg=${b.base0D},bold"`,
      `set -g window-status-activity-style "fg=${b.base0A},bg=${b.base01}"`,
      `set -g window-status-bell-style "fg=${b.base08},bg=${b.base01}"`,
      `set -g clock-mode-colour "${b.base0D}"`,
      `set -g display-panes-colour "${b.base04}"`,
      `set -g display-panes-active-colour "${b.base0D}"`,
    ].join("\n") + "\n"
  );
}

export function slackJsonText(variant: Variant, b: Base16): string {
  return sortedJson({
    mode: variant,
    background: b.base00!,
    accent: b.base0D!,
    green: b.base0B!,
    red: b.base08!,
  });
}

export function fcitx5ThemeText(b: Base16): string {
  const margin = (l: number, r: number, t: number, bt: number): string[][] => [
    ["Left", String(l)],
    ["Right", String(r)],
    ["Top", String(t)],
    ["Bottom", String(bt)],
  ];
  const frame = (): string[][] => [
    ["Color", b.base00!],
    ["BorderColor", b.base02!],
    ["BorderWidth", "2"],
  ];
  const sections: [string, string[][]][] = [
    [
      "Metadata",
      [
        ["Name", "Marchyo"],
        ["Version", "1"],
        ["Author", "Marchyo"],
        ["Description", "Generated from the current Marchyo theme"],
        ["ScaleWithDPI", "True"],
      ],
    ],
    [
      "InputPanel",
      [
        ["NormalColor", b.base05!],
        ["HighlightCandidateColor", b.base00!],
        ["HighlightColor", b.base00!],
        ["HighlightBackgroundColor", b.base0D!],
        ["PageButtonAlignment", "Last Candidate"],
      ],
    ],
    ["InputPanel/TextMargin", margin(12, 12, 8, 8)],
    ["InputPanel/ContentMargin", margin(6, 6, 6, 6)],
    ["InputPanel/Background", frame()],
    ["InputPanel/Background/Margin", margin(2, 2, 2, 2)],
    ["InputPanel/Highlight", [["Color", b.base0D!]]],
    ["InputPanel/Highlight/Margin", margin(8, 8, 5, 5)],
    ["InputPanel/PrevPage", [["Image", "prev.svg"]]],
    ["InputPanel/PrevPage/ClickMargin", margin(6, 6, 5, 5)],
    ["InputPanel/NextPage", [["Image", "next.svg"]]],
    ["InputPanel/NextPage/ClickMargin", margin(6, 6, 5, 5)],
    [
      "Menu",
      [
        ["NormalColor", b.base05!],
        ["HighlightCandidateColor", b.base00!],
      ],
    ],
    ["Menu/Background", frame()],
    ["Menu/Background/Margin", margin(2, 2, 2, 2)],
    ["Menu/ContentMargin", margin(6, 6, 6, 6)],
    ["Menu/CheckBox", [["Image", "radio.svg"]]],
    ["Menu/SubMenu", [["Image", "arrow.svg"]]],
    ["Menu/Highlight", [["Color", b.base0D!]]],
    ["Menu/Highlight/Margin", margin(8, 8, 5, 5)],
    ["Menu/Separator", [["Color", b.base03!]]],
    ["Menu/TextMargin", margin(12, 12, 8, 8)],
  ];
  return sections
    .map(
      ([name, kv]) =>
        `[${name}]\n` + kv.map(([k, v]) => `${k}=${v}\n`).join(""),
    )
    .join("\n");
}

export function herdrJsonText(b: Base16): string {
  const ansi = tty16FromBase16(b);
  return sortedJson({
    background: b.base00!,
    foreground: b.base05!,
    selection: b.base02!,
    cursor: ansi[15]!,
    ansi,
    colors: {
      accent: b.base0D!,
      accent_foreground: b.base00!,
      solid: b.base0D!,
      solid_foreground: b.base00!,
    },
  });
}

// Theme-dir file names modules/home/theme-runtime.nix ships for these
// surfaces (tests/cli/theme-surfaces-test.js keeps both lists equal).
export const APP_SURFACE_FILES = [
  "vscode-theme.json",
  "obsidian.css",
  "tmux.conf",
  "slack.json",
  "fcitx5-theme.conf",
  "herdr.json",
] as const;

export function appSurfaceTexts(
  variant: Variant,
  b: Base16,
): Record<(typeof APP_SURFACE_FILES)[number], string> {
  return {
    "vscode-theme.json": vscodeThemeText(variant, b),
    "obsidian.css": obsidianCssText(b),
    "tmux.conf": tmuxConfText(b),
    "slack.json": slackJsonText(variant, b),
    "fcitx5-theme.conf": fcitx5ThemeText(b),
    "herdr.json": herdrJsonText(b),
  };
}

// Surfaces `theme generate` fills from the build-variant dir's templates/
// (placeholders resolved by fillTemplate), not from base16 slots. A surface
// without a template there is disabled declaratively and is not written.
export const TEMPLATE_SURFACE_FILES = [
  "mako.conf",
  "waybar.css",
  "gtk.css",
  "btop.theme",
  "kitty.conf",
  "foot-theme.ini",
  "alacritty-theme.toml",
  "helix-theme.toml",
  "nvim-theme.lua",
  "emacs-theme.el",
] as const;
