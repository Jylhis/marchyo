{
  lib,
  pkgs,
  config,
  osConfig ? { },
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
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # Shared exec strings, bound on both the Print key and Super+S (see
  # below). The pipelines live in the marchyo CLI (capture.ts); these binds
  # are thin dispatchers.
  sattyCmd = "marchyo capture screenshot --edit";
  ocrCmd = "marchyo capture ocr";
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
        grimblast # Screenshot utility for Hyprland
        jq # Required by grimblast
      ]
      ++ lib.optionals cfg.enableAnnotation [
        satty # Screenshot annotation tool
      ]
      ++ lib.optionals cfg.enableOcr [
        tesseract # OCR engine (screenshot-to-text)
        slurp # region selection for the OCR bind
        wl-clipboard # wl-copy for the OCR bind
      ];

    home.file."${cfg.directory}/.keep".text = "";

    wayland.windowManager.hyprland.settings = {
      bind = [
        # Screenshot area/window selection (interactive)
        (hlua.bindd "Print" "Screenshot area/window" (hlua.exec "marchyo capture screenshot"))
        (hlua.bindd "SUPER + S" "Screenshot area/window" (hlua.exec "marchyo capture screenshot"))

        # Screenshot active window
        (hlua.bindd "SHIFT + Print" "Screenshot active window" (
          hlua.exec "marchyo capture screenshot --target active"
        ))
        (hlua.bindd "SUPER + CTRL + S" "Screenshot active window" (
          hlua.exec "marchyo capture screenshot --target active"
        ))

        # Screenshot current output (fullscreen)
        (hlua.bindd "CTRL + Print" "Screenshot current screen" (
          hlua.exec "marchyo capture screenshot --target output"
        ))
        (hlua.bindd "SUPER + ALT + S" "Screenshot current screen" (
          hlua.exec "marchyo capture screenshot --target output"
        ))

        # Screenshot all screens
        (hlua.bindd "ALT + Print" "Screenshot all screens" (
          hlua.exec "marchyo capture screenshot --target screen"
        ))
        (hlua.bindd "SUPER + CTRL + ALT + S" "Screenshot all screens" (
          hlua.exec "marchyo capture screenshot --target screen"
        ))
      ]
      ++ lib.optionals cfg.enableAnnotation [
        # Screenshot with annotation
        (hlua.bindd "SUPER + SHIFT + Print" "Screenshot with annotation" (hlua.exec sattyCmd))
        (hlua.bindd "SUPER + SHIFT + S" "Screenshot with annotation" (hlua.exec sattyCmd))
      ]
      ++ lib.optionals cfg.enableOcr [
        # OCR: select a region, extract text to clipboard
        (hlua.bindd "SUPER + SHIFT + O" "OCR region to clipboard" (hlua.exec ocrCmd))
        (hlua.bindd "SUPER + CTRL + SHIFT + S" "OCR region to clipboard" (hlua.exec ocrCmd))
      ];

      # Environment variable for grimblast to use the correct directory
      env = [
        (hlua.env "XDG_SCREENSHOTS_DIR" cfg.directory)
      ];
    };
  };
}
