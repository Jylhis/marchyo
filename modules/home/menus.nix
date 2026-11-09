# Power/session menu (SUPER+Escape) and system menu (SUPER+ALT+Space). The gum
# TUI logic lives in the marchyo CLI (`marchyo menu [power]`); this module keeps
# the tool closure installed and binds floating ghostty windows, reusing the
# org.omarchy.terminal class so hyprland.nix's centered floating-window rule applies.
{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && osConfig.marchyo.desktop.enable;
  enabled = desktopEnabled && osConfig.marchyo.menus.enable;
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
      speedtest-go # Trigger > Speed test > Network
      fio # Trigger > Speed test > Disk
    ];
  };
}
