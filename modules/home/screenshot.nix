{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  cfg = config.marchyo.screenshot;
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && osConfig.marchyo.desktop.enable;
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

    enableOcr = mkOption {
      type = types.bool;
      default = true;
      description = "Enable tesseract OCR (select a region, extract text to clipboard)";
    };
  };

  config = mkIf (desktopEnabled && cfg.enable) {
    home.packages =
      with pkgs;
      [
        grimblast
        jq # Required by grimblast
      ]
      ++ lib.optionals cfg.enableAnnotation [
        satty
      ]
      ++ lib.optionals cfg.enableOcr [
        tesseract
        slurp # region selection for the OCR bind
        wl-clipboard # wl-copy for the OCR bind
      ];

    home.file."${cfg.directory}/.keep".text = "";

    wayland.windowManager.hyprland.settings = {
      # grimblast reads XDG_SCREENSHOTS_DIR for the save directory.
      env = [
        (hlua.env "XDG_SCREENSHOTS_DIR" cfg.directory)
      ];
    };
  };
}
