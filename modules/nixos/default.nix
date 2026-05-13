{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo.theme;
  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    inherit (cfg) variant;
  };
in
{
  imports = (import ../../lib/discover-modules.nix { inherit lib; }) ./. ++ [
    ../generic/shell.nix
    ../generic/packages.nix
    ../generic/git.nix
    ../generic/fontconfig.nix
    ../generic/theme.nix
  ];

  config = {
    stylix = {
      enable = true;
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
  };
}
