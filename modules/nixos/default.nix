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
  imports = [
    ./nix-settings.nix
    ./printing.nix
    ./_1password.nix
    ../generic/shell.nix
    ../generic/packages.nix
    ../generic/git.nix
    ../generic/fontconfig.nix
    ../generic/theme.nix
    ./boot.nix
    ./console.nix
    ./options.nix
    ./input-migration.nix
    ./packages.nix
    ./containers.nix
    ./defaults.nix
    ./desktop-config.nix
    ./development-config.nix
    ./fcitx5.nix
    ./keyboard.nix
    ./fonts.nix
    ./graphics.nix
    ./hardware.nix
    ./help.nix
    ./hyprland.nix
    ./hyprlock.nix
    ./locale.nix
    ./media.nix
    ./network.nix
    ./performance.nix
    ./plymouth.nix
    ./security.nix
    ./system.nix
    ./tracking
    ./wayland.nix
    ./update-diff.nix
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
