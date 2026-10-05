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
