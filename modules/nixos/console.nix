# Uses `palette.tty16` not `palette.ansi16`: the kernel virtual console uses slot
# 0 as the actual screen background, so slots 0/7/15 come from the semantic
# palette (bg/text/text-heading). The raw ansi black/white slots are tuned for
# terminal apps that paint their own light bg and would leave the light-variant
# TTY unreadable. earlySetup applies the palette before any login prompt renders.
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
