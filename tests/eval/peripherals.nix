# Camera access at login.
{ lib, ... }:
{
  refs = {
    desktop.eval-camera-wait-desktop-default =
      config:
      config.marchyo.hardware.camera.waitForAccess
      && builtins.any (lib.hasSuffix "marchyo-wait-camera-access") (
        map toString config.systemd.user.services.wireplumber.serviceConfig.ExecStartPre
      );

    headless.eval-camera-wait-off =
      config:
      !config.marchyo.hardware.camera.waitForAccess
      && !(
        config.systemd.user.services ? wireplumber
        && config.systemd.user.services.wireplumber.serviceConfig ? ExecStartPre
      );
  };
}
