{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.marchyo.keybindingsHelp;
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # The cheat sheet is `marchyo keybindings`: it lists marchyo/keybindings.json,
  # which modules/home/keybinds.nix writes from the bind table, plus any
  # described bind added downstream (from `hyprctl binds`). fzf presents it.
in
{
  options.marchyo.keybindingsHelp = {
    enable = mkEnableOption "on-screen Hyprland keybinding cheat sheet (SUPER+K)" // {
      default = true;
    };
  };

  config = mkIf (desktopEnabled && cfg.enable) {
    home.packages = [ pkgs.fzf ];
  };
}
