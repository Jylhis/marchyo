_:
let
  login = c: c.services.logind.settings.Login;
in
{
  refs = {
    headless.eval-power-defaults =
      c:
      (login c).HandleLidSwitch == "suspend"
      && (login c).HandleLidSwitchExternalPower == "suspend"
      && (login c).HandleLidSwitchDocked == "ignore"
      && !(c.environment.etc ? "marchyo/hibernation");

    # headless-tweaks: lid = { onBattery = "hibernate"; onAC = "lock"; docked = "suspend"; }.
    headless-tweaks.eval-power-lid-custom =
      c:
      (login c).HandleLidSwitch == "hibernate"
      && (login c).HandleLidSwitchExternalPower == "lock"
      && (login c).HandleLidSwitchDocked == "suspend";

    # headless-tweaks-2: hibernation with a 30min delay and a resumeDevice.
    headless-tweaks-2.eval-power-hibernation =
      c:
      c.boot.resumeDevice == "/dev/disk/by-uuid/0f0c0a5e-0000-4000-8000-000000000000"
      && c.systemd.sleep.settings.Sleep.HibernateDelaySec == "30min"
      && (login c).HandleLidSwitch == "suspend-then-hibernate"
      && c.environment.etc ? "marchyo/hibernation";

    # headless-tweaks-3: hibernation with a swap device instead of resumeDevice.
    headless-tweaks-3.eval-power-hibernation-swap-device =
      c: c.marchyo.power.hibernation.enable && c.swapDevices != [ ];
  };

  # misconfigured: hibernation with neither a resumeDevice nor a swap device.
  failing.eval-power-hibernation-needs-swap = {
    on = "misconfigured";
    expect = "marchyo.power.hibernation.enable needs";
  };

  failingConfig.misconfigured.marchyo.power.hibernation.enable = true;

  refConfig = {
    headless-tweaks.marchyo.power.lid = {
      onBattery = "hibernate";
      onAC = "lock";
      docked = "suspend";
    };
    headless-tweaks-2 = {
      marchyo.power.hibernation = {
        enable = true;
        suspendThenHibernateDelay = "30min";
      };
      boot.resumeDevice = "/dev/disk/by-uuid/0f0c0a5e-0000-4000-8000-000000000000";
    };
    headless-tweaks-3 = {
      marchyo.power.hibernation.enable = true;
      swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];
    };
  };
}
