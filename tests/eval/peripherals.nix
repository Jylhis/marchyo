# Audio tuner, Cam Link 4K relay and camera access at login.
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  eval-audio-tuner-default-off = testNixOSCheck "audio-tuner-default-off" (
    config:
    !config.marchyo.audio.tuner.enable
    && config.marchyo.audio.tuner.profile == null
    && !(config.systemd.user.services ? marchyo-speaker-tuning)
  ) (withTestUser { });

  eval-audio-tuner-package =
    testNixOSCheck "audio-tuner-package"
      (
        config:
        builtins.any (p: (p.pname or "") == "omarchy-audio-tuner") config.environment.systemPackages
        && !(config.systemd.user.services ? marchyo-speaker-tuning)
      )
      (withTestUser {
        marchyo.audio.tuner.enable = true;
      });

  eval-audio-tuner-profile =
    testNixOSCheck "audio-tuner-profile"
      (
        config:
        let
          unit = config.systemd.user.services.marchyo-speaker-tuning;
        in
        lib.hasInfix "sof_sdw" unit.serviceConfig.ExecStart
        && unit.wantedBy == [ "graphical-session.target" ]
        && unit.environment ? LV2_PATH
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.audio.tuner = {
          enable = true;
          profile = "dell-xps-2026";
        };
      });

  eval-camlink-default-off = testNixOSCheck "camlink-default-off" (
    config: !config.marchyo.hardware.camlink.enable && !(config.systemd.services ? v4l2-relayd-camlink)
  ) (withTestUser { });

  eval-camlink-enabled =
    testNixOSCheck "camlink-enabled"
      (
        config:
        let
          unit = config.systemd.services.v4l2-relayd-camlink;
          rules = lib.concatMapStrings (p: toString p) config.services.udev.packages;
        in
        unit.wantedBy == [ ]
        && builtins.elem "dev-camlink4k.device" unit.bindsTo
        && config.services.v4l2-relayd.instances.camlink.cardLabel == "Cam Link 4K"
        && builtins.elem "v4l2loopback" config.boot.kernelModules
        && lib.hasInfix "71-marchyo-camlink4k" rules
        && builtins.elem "video" config.users.users.testuser.extraGroups
      )
      (withTestUser {
        marchyo.hardware.camlink.enable = true;
      });

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
