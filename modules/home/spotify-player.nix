# Per-user spotify-player (TUI Spotify client). Active as the selected
# marchyo.defaults.musicPlayer; the Super+M bind (hyprland.nix) launches it
# in a floating terminal. The theme palette (lib/theme-generators.nix
# spotifyPlayerPaletteFromSlots) mirrors the retired Stylix spotify-player
# target's slot mapping; slots come from modules/generic/theme-slots.nix
# (Jylhis pair by variant, or marchyo.theme.scheme's catalog palette). On a
# Linux desktop theme.toml links to the runtime theme layer's
# current-theme/spotify-player-theme.toml, read at each spotify-player start.
{
  config,
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
  runtimeThemed = themeEnabled && pkgs.stdenv.hostPlatform.isLinux;
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    variant = theme.variant or "dark";
    scheme = theme.scheme or null;
  };
  gen = import ../../lib/theme-generators.nix { inherit lib; };
in
{
  config = lib.mkIf enabled (
    lib.mkMerge [
      {
        programs.spotify-player = {
          enable = true;
          settings.theme = lib.mkIf themeEnabled "jylhis";
          themes = lib.mkIf (themeEnabled && !runtimeThemed) [
            {
              name = "jylhis";
              palette = gen.spotifyPlayerPaletteFromSlots s;
            }
          ];
        };
      }
      (lib.mkIf runtimeThemed {
        xdg.configFile."spotify-player/theme.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/marchyo/current-theme/spotify-player-theme.toml";
      })
    ]
  );
}
