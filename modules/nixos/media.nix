{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # File format support
    libheif

    # Players (music streaming handled by marchyo.defaults.musicPlayer)
    mpv
  ];
}
