# Per-user ncspot (TUI Spotify client), enabled when it is the selected
# marchyo.defaults.musicPlayer. Launched by the Super+M keybind (hyprland.nix).
# The theme mirrors the retired Stylix ncspot target's slot mapping; slots
# come from modules/generic/theme-slots.nix (Jylhis pair by variant, or
# marchyo.theme.scheme's catalog palette).
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled = (osConfig.marchyo.desktop.enable or false) && (defaults.musicPlayer or null) == "ncspot";
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
    programs.ncspot = {
      enable = true;
      settings.theme = lib.mkIf themeEnabled (
        with s;
        {
          background = base00;
          playing_bg = base00;
          primary = base05;
          secondary = base04;
          title = base06;
          playing = base0B;
          playing_selected = base0B;
          highlight = base05;
          highlight_bg = base02;
          error = base05;
          error_bg = base08;
          statusbar = base00;
          statusbar_progress = base04;
          statusbar_bg = base04;
          cmdline = base02;
          cmdline_bg = base05;
          search_match = base05;
        }
      );
    };
  };
}
