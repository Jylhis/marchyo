{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  cfg = config.marchyo.keybindingsHelp;
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # Cheatsheet logic lives in the marchyo CLI (`marchyo keybindings`); reading
  # binds at runtime keeps the sheet in sync with the actual running config,
  # including downstream-added binds. fzf is the CLI's presentation dependency.
in
{
  options.marchyo.keybindingsHelp = {
    enable = mkEnableOption "on-screen Hyprland keybinding cheat sheet (SUPER+K)" // {
      default = true;
    };
  };

  config = mkIf (desktopEnabled && cfg.enable) {
    home.packages = [ pkgs.fzf ];

    # Reuse the existing floating-terminal class so the overlay picks up the
    # centered floating-window rule from hyprland.nix without a new windowrule.
    wayland.windowManager.hyprland.settings.bind = [
      (hlua.bindd "SUPER + K" "Keybindings cheat sheet" (hlua.execInTerminal "marchyo keybindings"))
    ];
  };
}
