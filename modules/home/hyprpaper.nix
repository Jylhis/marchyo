{ config, pkgs, ... }:
let
  selectedWallpaper = "kanagawa-1.png";
  wallpaperDir = "Pictures/Wallpapers";
  wallpaper_path = "${config.home.homeDirectory}/${wallpaperDir}/${selectedWallpaper}";
in
{
  home.file = {
    "${wallpaperDir}" = {
      source = ../../assets/wallpapers;
      recursive = true;
    };
  };

  # Manually generate config to avoid systemd service issues with environment variables
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = ${wallpaper_path}
    wallpaper = ,${wallpaper_path}
  '';

  # Ensure hyprpaper is installed
  home.packages = [ pkgs.hyprpaper ];
}
