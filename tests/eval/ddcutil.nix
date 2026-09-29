{
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasDdcutil = cfg: builtins.any (p: lib.getName p == "ddcutil") cfg.environment.systemPackages;
  i2cOn = cfg: cfg.hardware.i2c.enable;
  userInI2c = cfg: builtins.elem "i2c" (cfg.users.users.testuser.extraGroups or [ ]);
in
{
  # Desktop default: i2c bus enabled, ddcutil installed, user in the i2c group.
  eval-ddcutil-desktop-default =
    testNixOSCheck "ddcutil-desktop-default" (cfg: i2cOn cfg && hasDdcutil cfg && userInI2c cfg)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Opting out keeps the desktop but drops i2c access + ddcutil.
  eval-ddcutil-disabled =
    testNixOSCheck "ddcutil-disabled" (cfg: !(i2cOn cfg) && !(hasDdcutil cfg) && !(userInI2c cfg))
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.hardware.ddc.enable = false;
      });

  # Headless: sub-toggle defaults true but the desktop gate keeps it inert.
  eval-ddcutil-headless = testNixOSCheck "ddcutil-headless" (cfg: !(i2cOn cfg) && !(hasDdcutil cfg)) (
    withTestUser { }
  );
}
