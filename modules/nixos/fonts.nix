{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Fonts — fontconfig.nix (generic) is option-guarded and harmless to import
  # unconditionally; the font packages below are a desktop concern.
  imports = [
    ../generic/fontconfig.nix
  ];
  config = lib.mkIf config.marchyo.desktop.enable {
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
  };
}
