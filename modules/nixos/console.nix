# Linux virtual console (TTY) theming.
#
# Sets the 16-color ANSI palette from the Jylhis Design System tokens.json so
# that:
#   - Any visible TTY (Ctrl+Alt+F2..F6, or the brief flash before greetd) uses
#     the brand palette.
#   - tuigreet (configured in boot.nix) inherits these colors via its --theme
#     CLI argument, which uses ANSI slot names (yellow/copper, etc.).
#
# `earlySetup = true` applies the palette before any login prompt renders.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    inherit (config.marchyo.theme) variant;
  };
in
{
  config = {
    console = {
      enable = true;
      earlySetup = true;
      colors = palette.ansi16;
      font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
      packages = [ pkgs.terminus_font ];
    };
  };
}
