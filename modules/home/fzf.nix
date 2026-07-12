# fzf with Jylhis design colors.
#
# Colors are set via programs.fzf.colors (merged into FZF_DEFAULT_OPTS
# alongside defaultOptions) from the Jylhis palette, mirroring the canonical
# generated set in ${jylhis-design-src}/platforms/shell/fzf-{roast,paper}.sh.
# The upstream Jylhis HM module's fzf target stays disabled in
# modules/home/jylhis-theme.nix: it mkForce-overwrites FZF_DEFAULT_OPTS (which
# would drop the layout options below), ships fewer color keys than the
# canonical shell files, and is Linux-gated — this works on darwin too.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeEnabled = (osConfig.marchyo or { }).theme.enable or true;
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };
in
{
  config = {
    programs.fzf = {
      enable = true;
      enableBashIntegration = lib.mkDefault true;
      enableZshIntegration = lib.mkDefault true;

      defaultCommand = lib.mkDefault "fd --type f --hidden --follow --exclude .git";
      defaultOptions = lib.mkDefault [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];

      colors = lib.mkIf themeEnabled (
        lib.mapAttrs (_: lib.mkDefault) {
          fg = palette.hex.text;
          bg = palette.hex.bg;
          hl = palette.hex.accent;
          "fg+" = palette.hex."text-heading";
          "bg+" = palette.hex."accent-subtle";
          "hl+" = palette.hex."accent-hover";
          info = palette.hex."text-muted";
          marker = palette.ansi.green;
          prompt = palette.hex.accent;
          spinner = palette.hex.accent;
          pointer = palette.hex.accent;
          header = palette.hex."text-muted";
          border = palette.hex.border;
          separator = palette.hex.border;
          gutter = palette.hex.bg;
        }
      );

      fileWidgetOptions = lib.mkDefault [
        "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      ];

      changeDirWidgetCommand = lib.mkDefault "fd --type d --hidden --follow --exclude .git";
      changeDirWidgetOptions = lib.mkDefault [
        "--preview 'eza --tree --level=2 --icons --color=always {}'"
      ];

      historyWidgetOptions = lib.mkDefault [
        "--sort"
        "--exact"
      ];
    };
  };
}
