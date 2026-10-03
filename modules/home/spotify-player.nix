# Per-user spotify-player (TUI Spotify client). Active as the selected
# marchyo.defaults.musicPlayer; the Super+M bind (hyprland.nix) launches it
# in a floating terminal. The theme palette mirrors the retired Stylix
# spotify-player target's slot mapping; slots come from
# modules/generic/theme-slots.nix (Jylhis pair by variant, or
# marchyo.theme.scheme's catalog palette).
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled =
    (osConfig.marchyo.desktop.enable or false) && (defaults.musicPlayer or null) == "spotify-player";
  theme = (osConfig.marchyo or { }).theme or { };
  themeEnabled = theme.enable or true;
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    variant = theme.variant or "dark";
    scheme = theme.scheme or null;
  };
in
{
  config = lib.mkIf enabled {
    programs.spotify-player = {
      enable = true;
      settings.theme = lib.mkIf themeEnabled "jylhis";
      themes = lib.mkIf themeEnabled [
        {
          name = "jylhis";
          palette = with s; {
            background = base00;
            foreground = base05;
            black = base00;
            red = base08;
            green = base0B;
            yellow = base0A;
            blue = base0D;
            magenta = base0E;
            cyan = base0C;
            white = base05;
            bright_black = base03;
            bright_red = base08;
            bright_green = base0B;
            bright_yellow = base0A;
            bright_blue = base0D;
            bright_magenta = base0E;
            bright_cyan = base0C;
            bright_white = base07;
          };
        }
      ];
    };
  };
}
