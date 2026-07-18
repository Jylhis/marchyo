{ lib, ... }:
{
  options.marchyo.osd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        On-screen display for volume/brightness via SwayOSD (auto-enabled with
        desktop). When enabled, the SwayOSD server runs as a user service and
        the Hyprland volume/brightness media keys route through
        `swayosd-client`, showing an overlay on change. Set false to keep the
        silent wpctl/brightnessctl bindings.
      '';
    };
  };
}
