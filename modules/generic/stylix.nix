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
  stylix = {
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
  };
}
