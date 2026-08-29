{ lib, ... }:
{
  options.marchyo.osd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        On-screen display for volume/brightness (auto-enabled with desktop).
        When enabled, the SwayOSD server runs as a user service and the Hyprland
        volume/brightness media keys route through `swayosd-client`, showing an
        overlay on change. Set false to keep the silent wpctl/brightnessctl
        bindings. When the unified `marchyo.shell` is enabled it provides its own
        native OSD instead, so SwayOSD stands down and the media keys take the
        silent path (the shell draws the overlay reactively).
      '';
    };
  };
}
