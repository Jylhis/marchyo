import type { Base16 } from "./matugen.ts";

// Application surfaces (lib/theme-generators.nix appSurfaceTexts), from base16
// slots, byte for byte.

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

// Theme-dir file names modules/home/theme-runtime.nix ships for these
// surfaces (tests/cli/theme-surfaces-test.js keeps both lists equal).
export const APP_SURFACE_FILES = ["tmux.conf", "fcitx5-theme.conf"] as const;

export function appSurfaceTexts(
  b: Base16,
): Record<(typeof APP_SURFACE_FILES)[number], string> {
  return {
    "tmux.conf": tmuxConfText(b),
    "fcitx5-theme.conf": fcitx5ThemeText(b),
  };
}

// Surfaces `theme generate` fills from the build-variant dir's templates/
// (placeholders resolved by fillTemplate), not from base16 slots. A surface
// without a template there is disabled declaratively and is not written.
export const TEMPLATE_SURFACE_FILES = [
  "gtk.css",
  "btop.theme",
  "kitty.conf",
  "foot-theme.ini",
  "alacritty-theme.toml",
  "helix-theme.toml",
  "nvim-theme.lua",
  "emacs-theme.el",
] as const;
