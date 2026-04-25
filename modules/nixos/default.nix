{
  pkgs,
  config,
  lib,
  ...
}:
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
        if config.marchyo.theme.variant == "dark" then
          "${pkgs.base16-schemes}/share/themes/nord.yaml"
        else
          "${pkgs.base16-schemes}/share/themes/nord-light.yaml";

      fonts = {
        serif = {
          package = pkgs.liberation_ttf;
          name = "Liberation Serif";
        };
        sansSerif = {

          package = pkgs.liberation_ttf;
          name = "Liberation Sans";
        };
        monospace = {
          package = pkgs.nerd-fonts.caskaydia-mono;
          name = "CaskaydiaMono Nerd Font";
        };
      };
    };
  };
}
