# OBS, Kdenlive and lazydocker are not installed by default, even with the
# desktop, media and development flags on.
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasPkg = name: cfg: lib.any (p: lib.getName p == name) cfg.environment.systemPackages;
in
{
  eval-app-defaults-no-obs =
    testNixOSCheck "app-defaults-no-obs" (cfg: !(hasPkg "obs-studio" cfg))
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.media.enable = true;
      });

  eval-app-defaults-no-kdenlive =
    testNixOSCheck "app-defaults-no-kdenlive" (cfg: !(hasPkg "kdenlive" cfg))
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.media.enable = true;
      });

  eval-app-defaults-no-lazydocker =
    testNixOSCheck "app-defaults-no-lazydocker" (cfg: !(hasPkg "lazydocker" cfg))
      (withTestUser {
        marchyo.development.enable = true;
      });
}
