# Linux virtual console (TTY) theming.
#
# Sets the 16-color console palette from the Jylhis Design System themes/jylhis.json
# so that any visible TTY (Ctrl+Alt+F2..F6) uses the brand palette.
#
# We use `palette.tty16` rather than `palette.ansi16`: slots 0/7/15 are taken
# from the semantic palette (bg / text / text-heading) instead of the raw
# `tokens.ansi` array, because the kernel virtual console uses slot 0 as the
# actual screen background — the `ansi.black`/`ansi.white`/`ansi.bright-white`
# slots are tuned for terminal apps that paint their own light bg, and would
# leave the light variant TTY unreadable.
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
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = config.marchyo.theme.fontScale;
  };
in
{
  config = {
    console = {
      enable = lib.mkDefault true;
      earlySetup = lib.mkDefault true;
      colors = palette.tty16;
      font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/${fs.terminusFont 24}.psf.gz";
      packages = [ pkgs.terminus_font ];
    };
  };
}
