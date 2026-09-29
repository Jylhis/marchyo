# Per-user ncspot (TUI Spotify client), enabled when it is the selected
# marchyo.defaults.musicPlayer. Launched by the Super+M keybind (hyprland.nix).
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
