{ config, lib, ... }:
let
  cfg = config.marchyo.power;
  hib = cfg.hibernation;

  sleepAction =
    action: if hib.enable && action == "suspend" then "suspend-then-hibernate" else action;
in
{
  config = lib.mkMerge [
    {
      services.logind.settings.Login = {
        HandleLidSwitch = lib.mkDefault (sleepAction cfg.lid.onBattery);
        HandleLidSwitchExternalPower = lib.mkDefault (sleepAction cfg.lid.onAC);
        HandleLidSwitchDocked = lib.mkDefault cfg.lid.docked;
      };
    }

    (lib.mkIf hib.enable {
      assertions = [
        {
          assertion = config.swapDevices != [ ] || config.boot.resumeDevice != "";
          message = "marchyo.power.hibernation.enable needs swapDevices or boot.resumeDevice.";
        }
      ];

      services.logind.settings.Login.HandleSuspendKey = lib.mkDefault "suspend-then-hibernate";

      systemd.sleep.settings.Sleep.HibernateDelaySec = hib.suspendThenHibernateDelay;

      environment.etc."marchyo/hibernation".text = "enabled\n";
    })
  ];
}
