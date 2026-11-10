# Themed tmux. The colours (lib/theme-generators.nix tmuxConfText) are baked in
# at build time from modules/generic/theme-slots.nix; on a desktop the runtime
# layer's current-theme/tmux.conf is sourced after them, so `marchyo theme`
# restyles new and (through `tmux source-file`) running servers. The
# SUPER+ALT+Return "Work" session bind lives in omarchy-binds.nix.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  marchyoCfg = osConfig.marchyo;
  inherit (marchyoCfg) theme;
  themeEnabled = theme.enable;
  runtimeThemed = themeEnabled && pkgs.stdenv.hostPlatform.isLinux && marchyoCfg.desktop.enable;
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    inherit (theme) variant scheme;
  };
  gen = import ../../lib/theme-generators.nix { inherit lib; };
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && marchyoCfg.tmux.enable) {
    programs.tmux = {
      enable = true;
      terminal = "tmux-256color";
      mouse = true;
      keyMode = "vi";
      baseIndex = 1;
      escapeTime = 0;
      historyLimit = 50000;
      aggressiveResize = true;
      focusEvents = true;
      extraConfig = ''
        set -ag terminal-overrides ",*:RGB"
        set -g renumber-windows on
        setw -g pane-base-index 1
        set -g set-clipboard on
        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi y send -X copy-selection-and-cancel
      ''
      + lib.optionalString themeEnabled (gen.tmuxConfText s)
      + lib.optionalString runtimeThemed ''
        source-file -q ${config.xdg.configHome}/marchyo/current-theme/tmux.conf
      '';
    };
  };
}
