# Omarchy-style power/session menu (SUPER+Escape) and central system menu
# (SUPER+ALT+Space). The gum TUI logic lives in the marchyo CLI
# (`marchyo menu [power]`, packages/marchyo-cli commands/menu.ts — absorbed
# from the old marchyo-menu/marchyo-power-menu scripts); this module keeps
# the tool closure installed and binds the floating ghostty windows, reusing
# the org.omarchy.terminal class so the centered floating-window rule from
# hyprland.nix applies (same pattern as keybindings-cheatsheet.nix).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  desktopEnabled = pkgs.stdenv.isLinux && (osConfig.marchyo.desktop.enable or false);
  enabled = desktopEnabled && (osConfig.marchyo.menus.enable or true);
in
{
  config = mkIf enabled {
    # Tools the CLI menus shell out to (gum prompts, setup TUIs, power
    # profile control). grimblast/hyprpicker for the Trigger entries come
    # from screenshot.nix / hyprland.nix.
    home.packages = with pkgs; [
      gum
      wiremix
      networkmanager # nmtui
      bluetui
      hyprmon
      power-profiles-daemon # powerprofilesctl
    ];

    # Merges with the bindd lists from hyprland.nix / screenshot.nix /
    # webapps.nix (home-manager concatenates the lists). Both combos were
    # verified free in hyprland.nix.
    wayland.windowManager.hyprland.settings.bindd = [
      "SUPER, Escape, Power menu, exec, $terminal --class=org.omarchy.terminal -e marchyo menu power"
      "SUPER ALT, Space, System menu, exec, $terminal --class=org.omarchy.terminal -e marchyo menu"
    ];
  };
}
