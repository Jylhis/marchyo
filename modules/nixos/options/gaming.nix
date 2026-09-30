{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.gaming = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the gaming bundle: Steam (with the Steam hardware udev rules and
        Xbox controller support), GameMode, Gamescope, MangoHUD, and the Lutris
        and Heroic launchers plus ProtonUp-Qt.

        Only takes effect together with `marchyo.desktop.enable`; unlike office
        and media it is not auto-enabled by the desktop, so a plain desktop
        stays lean unless you opt in. Steam pulls in 32-bit graphics and is
        x86_64-only, so the bundle is a no-op on other architectures.
      '';
    };
  };
}
