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

      fonts = {
        serif = {
          package = pkgs.literata;
          name = "Literata";
        };
        sansSerif = {
          package = pkgs.liberation_ttf;
          name = "Liberation Sans";
        };
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font";
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
