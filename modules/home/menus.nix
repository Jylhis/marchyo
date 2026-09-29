# Power/session menu (SUPER+Escape) and system menu (SUPER+ALT+Space). The gum
# TUI logic lives in the marchyo CLI (`marchyo menu [power]`); this module keeps
# the tool closure installed and binds floating ghostty windows, reusing the
# org.omarchy.terminal class so hyprland.nix's centered floating-window rule applies.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && (osConfig.marchyo.desktop.enable or false);
  enabled = desktopEnabled && (osConfig.marchyo.menus.enable or true);
in
{
  config = mkIf enabled {
    # Tools the CLI menus shell out to; grimblast/hyprpicker come from
    # screenshot.nix / hyprland.nix.
    home.packages = with pkgs; [
      gum
      wiremix
      networkmanager # nmtui
      bluetui
      hyprmon
      power-profiles-daemon # powerprofilesctl
    ];

    # Merges with the bind lists from other home modules; both combos verified free.
    wayland.windowManager.hyprland.settings.bind = [
      (hlua.bindd "SUPER + Escape" "Power menu" (hlua.execInTerminal "marchyo menu power"))
      (hlua.bindd "SUPER + ALT + Space" "System menu" (hlua.execInTerminal "marchyo menu"))
    ];
  };
}
