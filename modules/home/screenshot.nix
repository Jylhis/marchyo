{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  cfg = config.marchyo.screenshot;
  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";
in
{
  options.marchyo.screenshot = {
    enable = mkEnableOption "Screenshot functionality for Hyprland" // {
      default = true;
    };

    directory = mkOption {
      type = types.str;
      default = screenshotDir;
      description = "Directory where screenshots will be saved";
    };

    enableAnnotation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable satty for screenshot annotation";
    };
  };

  config = mkIf cfg.enable {
    # Install screenshot tools
    home.packages =
      with pkgs;
      [
        grimblast # Screenshot utility for Hyprland
        jq # Required by grimblast
      ]
      ++ lib.optionals cfg.enableAnnotation [
        satty # Screenshot annotation tool
      ];

    # Create screenshot directory
    home.file."${cfg.directory}/.keep".text = "";

    # Hyprland keybindings for screenshots
    wayland.windowManager.hyprland.settings = {
      bindd = [
        # Screenshot area/window selection (interactive)
        ", Print, Screenshot area/window, exec, grimblast --notify --freeze copysave area"

        # Screenshot active window
        "SHIFT, Print, Screenshot active window, exec, grimblast --notify --cursor copysave active"

        # Screenshot current output (fullscreen)
        "CTRL, Print, Screenshot current screen, exec, grimblast --notify copysave output"

        # Screenshot all screens
        "ALT, Print, Screenshot all screens, exec, grimblast --notify copysave screen"
      ]
      ++ lib.optionals cfg.enableAnnotation [
        # Screenshot with annotation
        "SUPER SHIFT, Print, Screenshot with annotation, exec, grimblast --freeze save area - | satty --filename - --output-filename ${cfg.directory}/$(date '+%Y-%m-%d_%H-%M-%S')_annotated.png"
      ];

      # Environment variable for grimblast to use the correct directory
      env = [
        "XDG_SCREENSHOTS_DIR,${cfg.directory}"
      ];
    };
  };
}
