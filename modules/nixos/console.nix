# Linux virtual console (TTY) theming.
#
# Sets the 16-color console palette from the Jylhis Design System tokens.json
# so that:
#   - Any visible TTY (Ctrl+Alt+F2..F6, or the brief flash before greetd) uses
#     the brand palette.
#   - tuigreet (configured in boot.nix) inherits these colors via its --theme
#     CLI argument, which uses ANSI slot names (yellow/copper, etc.).
#
# We use `palette.tty16` rather than `palette.ansi16`: slots 0/7/15 are taken
# from the semantic palette (bg / text / text-heading) instead of the raw
# `tokens.ansi` array, because the kernel virtual console uses slot 0 as the
# actual screen background — the `ansi.black`/`ansi.white`/`ansi.bright-white`
# slots are tuned for terminal apps that paint their own paper bg, and would
# leave the Paper variant TTY (and tuigreet) unreadable.
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
      colors = palette.tty16;
      font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
      packages = [ pkgs.terminus_font ];
    };
  };
}
