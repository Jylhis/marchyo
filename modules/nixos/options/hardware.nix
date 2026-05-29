{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.hardware = {
    logitech.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Logitech wireless device support (Solaar GUI + udev rules).";
    };
  };
}
