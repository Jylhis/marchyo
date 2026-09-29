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

    ddc.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable DDC/CI control of external monitors (brightness/contrast over the
        i2c bus via ddcutil). Auto-enabled with the desktop: it loads the
        i2c-dev module and its udev rules (`hardware.i2c.enable`), installs
        ddcutil, and adds Marchyo users to the `i2c` group. Set to false to keep
        the desktop but skip i2c access. Only affects external displays
        connected over DP/HDMI/VGA; laptop panels use backlight controls.
      '';
    };
  };
}
