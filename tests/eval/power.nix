{ helpers, ... }:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    testNixOSFails
    withTestUser
    ;
  login = c: c.services.logind.settings.Login;
in
{
  eval-power-defaults = testNixOSCheck "power-defaults" (
    c:
    (login c).HandleLidSwitch == "suspend"
    && (login c).HandleLidSwitchExternalPower == "suspend"
    && (login c).HandleLidSwitchDocked == "ignore"
    && !(c.environment.etc ? "marchyo/hibernation")
  ) (withTestUser { });

  eval-power-lid-custom =
    testNixOSCheck "power-lid-custom"
      (
        c:
        (login c).HandleLidSwitch == "hibernate"
        && (login c).HandleLidSwitchExternalPower == "lock"
        && (login c).HandleLidSwitchDocked == "suspend"
      )
      (withTestUser {
        marchyo.power.lid = {
          onBattery = "hibernate";
          onAC = "lock";
          docked = "suspend";
        };
      });

  eval-power-hibernation =
    testNixOSCheck "power-hibernation"
      (
        c:
        c.boot.resumeDevice == "/dev/disk/by-uuid/0f0c0a5e-0000-4000-8000-000000000000"
        && c.systemd.sleep.settings.Sleep.HibernateDelaySec == "30min"
        && (login c).HandleLidSwitch == "suspend-then-hibernate"
        && c.environment.etc ? "marchyo/hibernation"
      )
      (withTestUser {
        marchyo.power.hibernation = {
          enable = true;
          suspendThenHibernateDelay = "30min";
        };
        boot.resumeDevice = "/dev/disk/by-uuid/0f0c0a5e-0000-4000-8000-000000000000";
      });

  eval-power-hibernation-needs-swap =
    testNixOSFails "power-hibernation-needs-swap" "marchyo.power.hibernation.enable needs"
      (withTestUser {
        marchyo.power.hibernation.enable = true;
      });

  eval-power-hibernation-swap-device = testNixOS "power-hibernation-swap-device" (withTestUser {
    marchyo.power.hibernation.enable = true;
    swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];
  });
}
