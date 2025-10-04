{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.marchyo.wallpaper = {
    enable = lib.mkEnableOption "wallpaper management" // {
      default = false;
    };

    manager = lib.mkOption {
      type = lib.types.enum [
        "swww"
        "hyprpaper"
        "waypaper"
      ];
      default = "swww";
      description = "Wallpaper manager to use";
    };

    defaultWallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to default wallpaper image";
      example = lib.literalExpression "./wallpapers/default.png";
    };
  };

  config = lib.mkIf config.marchyo.wallpaper.enable {
    home.packages =
      with pkgs;
      [
        # Always include waypaper as a GUI frontend
        waypaper
      ]
      ++ lib.optionals (config.marchyo.wallpaper.manager == "swww") [
        swww
      ]
      ++ lib.optionals (config.marchyo.wallpaper.manager == "hyprpaper") [
        hyprpaper
      ];

    # Auto-start wallpaper daemon for Hyprland
    wayland.windowManager.hyprland.settings.exec-once =
      lib.mkIf config.wayland.windowManager.hyprland.enable
        (
          lib.mkMerge [
            (lib.mkIf (config.marchyo.wallpaper.manager == "swww") [
              "swww-daemon"
              (lib.mkIf (
                config.marchyo.wallpaper.defaultWallpaper != null
              ) "swww img ${config.marchyo.wallpaper.defaultWallpaper}")
            ])
          ]
        );
  };
}
