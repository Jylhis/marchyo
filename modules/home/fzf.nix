# fzf with Jylhis design colors, set via programs.fzf.colors.
#
# The upstream Jylhis HM fzf target stays disabled in modules/home/jylhis-theme.nix:
# it mkForce-overwrites FZF_DEFAULT_OPTS (dropping the layout options below), ships
# fewer color keys, and is Linux-gated, whereas this works on darwin too.
{
  lib,
  pkgs,
  options,
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

  # HM master nests the widget options under programs.fzf.{fileWidget,...},
  # deprecating the flat *WidgetCommand/*WidgetOptions form that release-26.05 HM
  # (darwinConfigurations.x86_64 / stable-darwin checks) still declares. Pick the
  # shape the active HM declares so this stays warning-free on master and valid on stable.
  hasNestedWidgets = options.programs.fzf ? changeDirWidget;

  fileWidgetOptions = [
    "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
  ];
  changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  changeDirWidgetOptions = [
    "--preview 'eza --tree --level=2 --icons --color=always {}'"
  ];
  historyWidgetOptions = [
    "--sort"
    "--exact"
  ];

  widgetConfig =
    if hasNestedWidgets then
      {
        fileWidget.options = lib.mkDefault fileWidgetOptions;
        changeDirWidget.command = lib.mkDefault changeDirWidgetCommand;
        changeDirWidget.options = lib.mkDefault changeDirWidgetOptions;
        historyWidget.options = lib.mkDefault historyWidgetOptions;
      }
    else
      {
        fileWidgetOptions = lib.mkDefault fileWidgetOptions;
        changeDirWidgetCommand = lib.mkDefault changeDirWidgetCommand;
        changeDirWidgetOptions = lib.mkDefault changeDirWidgetOptions;
        historyWidgetOptions = lib.mkDefault historyWidgetOptions;
      };
in
{
  config = {
    programs.fzf = lib.mkMerge [
      {
        enable = true;
        enableBashIntegration = lib.mkDefault true;

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
      }
      widgetConfig
    ];
  };
}
