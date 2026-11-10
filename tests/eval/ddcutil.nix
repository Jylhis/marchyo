{ lib, ... }:
let
  hasDdcutil = cfg: builtins.any (p: lib.getName p == "ddcutil") cfg.environment.systemPackages;
  i2cOn = cfg: cfg.hardware.i2c.enable;
  userInI2c = cfg: builtins.elem "i2c" (cfg.users.users.testuser.extraGroups or [ ]);
in
{
  refs = {
    # Desktop default: i2c bus enabled, ddcutil installed, user in the i2c group.
    desktop.eval-ddcutil-desktop-default = cfg: i2cOn cfg && hasDdcutil cfg && userInI2c cfg;

    # Opting out (marchyo.hardware.ddc.enable = false) keeps the desktop but
    # drops i2c access + ddcutil.
    desktop-tweaks.eval-ddcutil-disabled = cfg: !(i2cOn cfg) && !(hasDdcutil cfg) && !(userInI2c cfg);

    # Headless: sub-toggle defaults true but the desktop gate keeps it inert.
    headless.eval-ddcutil-headless = cfg: !(i2cOn cfg) && !(hasDdcutil cfg);
  };

  refConfig.desktop-tweaks.marchyo.hardware.ddc.enable = false;
}
