# Per-user ncspot (TUI Spotify client).
#
# Enabled via Home-Manager's programs.ncspot when it is the selected
# marchyo.defaults.musicPlayer and desktop is enabled. The Hyprland Super+M
# keybind (modules/home/hyprland.nix) launches it in a floating terminal.
{
  osConfig ? { },
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled = (osConfig.marchyo.desktop.enable or false) && (defaults.musicPlayer or null) == "ncspot";
in
{
  config = lib.mkIf enabled {
    programs.ncspot.enable = true;
  };
}
