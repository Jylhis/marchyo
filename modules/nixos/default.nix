{ pkgs, ... }:
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
    ./theme-assertions.nix
    ./wayland.nix
    ./update-diff.nix
  ];
  config = {
    stylix = {
      enable = true;
      autoEnable = true;
      # packages = with pkgs; [
      # # Programming fonts (Nerd Font variants only)
      # nerd-fonts.caskaydia-mono
      # nerd-fonts.jetbrains-mono

      # # UI and reading fonts
      # inter # Modern UI font
      # source-serif-pro # High-quality serif font
      # liberation_ttf

      # ];

      image = ../../assets/wallpapers/kanagawa-1.png;
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
