# Camera access at login.
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  eval-camera-wait-desktop-default =
    testNixOSCheck "camera-wait-desktop-default"
      (
        config:
        config.marchyo.hardware.camera.waitForAccess
        && builtins.any (lib.hasSuffix "marchyo-wait-camera-access") (
          map toString config.systemd.user.services.wireplumber.serviceConfig.ExecStartPre
        )
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  eval-camera-wait-off =
    testNixOSCheck "camera-wait-off"
      (
        config:
        !config.marchyo.hardware.camera.waitForAccess
        && !(
          config.systemd.user.services ? wireplumber
          && config.systemd.user.services.wireplumber.serviceConfig ? ExecStartPre
        )
      )
      (withTestUser {
        marchyo.desktop.enable = false;
      });
}
