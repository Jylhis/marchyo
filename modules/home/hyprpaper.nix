{ config, ... }:
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

  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [
        wallpaper_path
      ];
      wallpaper = [
        ",${wallpaper_path}"
      ];
    };
  };
}
