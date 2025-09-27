{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # File format support
    libheif
    libheif.out

    # Players
    spotify
    mpv
  ];

}
