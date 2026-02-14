{ config, ... }:
let
  wallpaperDir = "Pictures/Wallpapers";
in
{
  home.file = {
    "${wallpaperDir}" = {
      source = ../../assets/wallpapers;
      recursive = true;
    };
  };

  stylix.image = ../../assets/wallpapers/kanagawa-1.png;

  # services.hyprpaper = {
  #   enable = true;
  #   settings = {
  #     preload = [
  #       wallpaper_path
  #     ];
  #     wallpaper = [
  #       ",${wallpaper_path}"
  #     ];
  #   };
  # };
}
