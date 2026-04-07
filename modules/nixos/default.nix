{ pkgs, config, ... }:
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
