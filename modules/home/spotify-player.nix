# Per-user spotify-player (TUI Spotify client). Active as the selected
# marchyo.defaults.musicPlayer; the Super+M bind (hyprland.nix) launches it
# in a floating terminal.
{
  osConfig ? { },
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled =
    (osConfig.marchyo.desktop.enable or false) && (defaults.musicPlayer or null) == "spotify-player";
in
{
  config = lib.mkIf enabled {
    programs.spotify-player.enable = true;
  };
}
