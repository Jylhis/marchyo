{ pkgs, ... }:
{
  # Fonts
  imports = [
    ../generic/fontconfig.nix
  ];
  # https://learn.omacom.io/2/the-omarchy-manual/94/fonts
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      # Programming fonts (Nerd Font variants only)
      nerd-fonts.caskaydia-mono
      nerd-fonts.jetbrains-mono

      # UI and reading fonts
      inter # Modern UI font
      source-serif-pro # High-quality serif font
      liberation_ttf

    ];
    fontconfig = {
      cache32Bit = true;

      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
        autohint = false;
      };

      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };
}
