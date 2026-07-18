# Hibernation (suspend-to-disk). Gated on marchyo.power.hibernation.enable;
# the resume device must be a swap device large enough to hold the RAM image
# (swap >= RAM). See disko/luks-btrfs.nix for partitioning notes.
{ config, lib, ... }:
let
  cfg = config.marchyo.power.hibernation;
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.resumeDevice != null;
            message = ''
              marchyo.power.hibernation.enable requires
              marchyo.power.hibernation.resumeDevice to point at a swap device
              (e.g. "/dev/disk/by-label/swap"). Hibernation writes the RAM
              image to swap, so the device needs swap >= RAM — see
              disko/luks-btrfs.nix for partition sizing notes.
            '';
          }
        ];

        boot.resumeDevice = lib.mkIf (cfg.resumeDevice != null) cfg.resumeDevice;
      }

      (lib.mkIf cfg.suspendThenHibernate {
        # Suspend first, hibernate after 45 minutes asleep.
        systemd.sleep.settings.Sleep.HibernateDelaySec = lib.mkDefault "45min";
        services.logind.settings.Login.HandleLidSwitch = lib.mkDefault "suspend-then-hibernate";
      })
    ]
  );
}
