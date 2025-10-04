{ config, lib, ... }:
{
  options.marchyo.chromium = {
    enable = lib.mkEnableOption "Chromium/Brave browser configuration" // {
      default = false;
    };

    commandLineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Wayland support
        "--ozone-platform=wayland"
        "--ozone-platform-hint=wayland"

        # Enable touchpad overscroll for history navigation
        "--enable-features=TouchpadOverscrollHistoryNavigation"
      ];
      description = "Command-line arguments for Chromium-based browsers";
    };
  };

  config = lib.mkIf config.marchyo.chromium.enable {
    # Apply flags to Brave
    programs.chromium = {
      enable = false; # Don't enable chromium by default, just configure it
      inherit (config.marchyo.chromium) commandLineArgs;
    };

    # Also create flags file for other Chromium-based browsers
    xdg.configFile."chromium-flags.conf".text =
      lib.concatStringsSep "\n" config.marchyo.chromium.commandLineArgs;
    xdg.configFile."brave-flags.conf".text =
      lib.concatStringsSep "\n" config.marchyo.chromium.commandLineArgs;
  };
}
