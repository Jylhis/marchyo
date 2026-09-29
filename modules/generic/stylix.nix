# Shared Stylix base config (base16 scheme + font stack) for NixOS and
# nix-darwin. Imported explicitly by their default.nix, NOT by Home Manager
# (system-level stylix options). The base16 palette derives from
# marchyo.theme.variant via jylhis-palette.nix; marchyo.theme.scheme overrides
# it with a scheme from the tinted-schemes catalog.
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
          "${pkgs.tinted-schemes-src}/base16/${cfg.scheme}.yaml"
        else
          palette.base16;

      # Stylix has only serif/sansSerif/monospace, so the slab display face
      # lands on `serif` and the grotesque body face on `sansSerif`. Monospace
      # is the Nerd Font patch of IBM Plex Mono ("BlexMono"), needed for the
      # glyphs in marchyo's desktop chrome (waybar, mako, hyprlock).
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

        # Scaled by marchyo.theme.fontScale. These cover the surfaces marchyo
        # leaves to stylix (Qt/KDE/GNOME/fontconfig apps); surfaces marchyo
        # themes directly scale from the same fontScale in their own modules.
        sizes = {
          applications = fs.round 12;
          terminal = fs.round 12;
          desktop = fs.round 10;
          popups = fs.round 10;
        };
      };
    }

    # Themed cursor out of the box (stylix sets none itself); mkDefault so a
    # consumer can swap it. stylix declares the cursor option only where its
    # module includes cursor.nix: the NixOS module does, the stable Darwin one
    # (release-26.05) does not, so guard on existence for the Darwin path.
    (lib.optionalAttrs (options.stylix ? cursor) {
      cursor = {
        name = lib.mkDefault "Adwaita";
        package = lib.mkDefault pkgs.adwaita-icon-theme;
        size = lib.mkDefault 24;
      };
    })
  ];
}
