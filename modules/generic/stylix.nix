# Shared Stylix base configuration for NixOS and nix-darwin.
#
# Single source of truth for the base16 scheme selection and the marchyo font
# stack. Imported explicitly by modules/nixos/default.nix and
# modules/darwin/default.nix (NOT by Home Manager — these are system-level
# stylix options). The base16 palette is derived from marchyo.theme.variant via
# modules/generic/jylhis-palette.nix; setting marchyo.theme.scheme overrides it
# with a base16-schemes YAML instead.
{
  pkgs,
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.marchyo.theme;
  palette = import ./jylhis-palette.nix {
    inherit pkgs lib;
    inherit (cfg) variant;
  };
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = cfg.fontScale;
  };
in
{
  stylix = lib.mkMerge [
    {
      autoEnable = true;
      base16Scheme =
        if cfg.scheme != null then
          "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml"
        else
          palette.base16;

      # Jylhis Design System v2 ("The Survey") three-role type stack:
      # display/headings = Zilla Slab, body = Hanken Grotesk, mono = IBM Plex
      # Mono. Stylix only has serif/sansSerif/monospace, so the slab display
      # face lands on `serif` and the grotesque body face on `sansSerif`.
      # Monospace uses the Nerd Font patch of IBM Plex Mono ("BlexMono"), which
      # marchyo's desktop chrome (waybar, mako, hyprlock) needs for glyphs.
      fonts = {
        serif = {
          package = pkgs.zilla-slab;
          name = "Zilla Slab";
        };
        sansSerif = {
          package = pkgs.hanken-grotesk;
          name = "Hanken Grotesk";
        };
        monospace = {
          package = pkgs.nerd-fonts.blex-mono;
          name = "BlexMono Nerd Font";
        };

        # Scaled by marchyo.theme.fontScale (single knob for all fonts). These
        # reach the surfaces marchyo leaves to stylix (Qt/KDE/GNOME/fontconfig
        # apps); the surfaces marchyo themes directly (ghostty, waybar, mako,
        # hyprlock, vicinae, gtk, console) scale from the same fontScale in
        # their own modules.
        sizes = {
          applications = fs.round 12;
          terminal = fs.round 12;
          desktop = fs.round 10;
          popups = fs.round 10;
        };
      };
    }

    # Themed cursor out of the box (stylix doesn't set one itself). mkDefault so
    # a consumer can swap the theme/package/size. stylix declares the cursor
    # option only where its module includes cursor.nix — its NixOS module does,
    # but the darwin module (release-26.05 / stylix-stable, used by
    # darwinConfigurations.x86_64) does not. Guard on existence so the stable
    # Darwin path evaluates; mirrors the hasStylix* guards in theme.nix.
    (lib.optionalAttrs (options.stylix ? cursor) {
      cursor = {
        name = lib.mkDefault "Adwaita";
        package = lib.mkDefault pkgs.adwaita-icon-theme;
        size = lib.mkDefault 24;
      };
    })
  ];
}
