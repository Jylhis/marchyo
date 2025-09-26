{ pkgs, ... }:
{
  # Fonts
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
      enable = true;
      cache32Bit = true;
      defaultFonts = {
        serif = [ "Liberation Serif" ];
        sansSerif = [ "Liberation Sans" ];
        monospace = [ "CaskaydiaMono Nerd Font" ];
      };
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
