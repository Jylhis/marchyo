{ pkgs, config, ... }:
let
  # Jylhis Design System base16 color mappings derived from tokens.json
  jylhisRoast = {
    scheme = "Jylhis Roast";
    author = "Markus Jylhankangas (jylhis.com)";
    base00 = "1a1714"; # bg
    base01 = "242019"; # bg-subtle
    base02 = "2a2520"; # surface
    base03 = "8a7f72"; # text-faint
    base04 = "b0a496"; # text-muted
    base05 = "e8e0d4"; # text
    base06 = "f0eae0"; # text-heading
    base07 = "363230"; # surface-raised
    base08 = "ff5f59"; # status-err
    base09 = "e89b5e"; # accent (copper)
    base0A = "d0bc00"; # status-warn
    base0B = "b3c785"; # syn-string
    base0C = "80c8b3"; # syn-type
    base0D = "2fafff"; # status-info
    base0E = "c8a5ff"; # syn-keyword
    base0F = "d4884a"; # brand
  };

  jylhisPaper = {
    scheme = "Jylhis Paper";
    author = "Markus Jylhankangas (jylhis.com)";
    base00 = "faf7f2"; # bg
    base01 = "f0ebe3"; # bg-subtle
    base02 = "e8e1d6"; # surface
    base03 = "8a7f72"; # text-faint
    base04 = "6b5f54"; # text-muted
    base05 = "2c2825"; # text
    base06 = "1e1b18"; # text-heading
    base07 = "fefdfb"; # surface-raised
    base08 = "a60000"; # status-err
    base09 = "9a5a2a"; # accent (copper)
    base0A = "6f5500"; # status-warn
    base0B = "3d5a1f"; # syn-string
    base0C = "134a4a"; # syn-type
    base0D = "0031a9"; # status-info
    base0E = "4a2d80"; # syn-keyword
    base0F = "b5703c"; # brand
  };

  cfg = config.marchyo.theme;
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
        else if cfg.variant == "dark" then
          jylhisRoast
        else
          jylhisPaper;

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
