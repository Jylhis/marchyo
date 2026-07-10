{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser minimalConfig;
in
{
  # avahi / firewall / zram are on by default (mkDefault) on any host.
  eval-omarchy-service-defaults = testNixOSCheck "omarchy-service-defaults" (
    cfg:
    cfg.services.avahi.enable
    && cfg.services.avahi.nssmdns4
    && cfg.networking.firewall.enable
    && cfg.zramSwap.enable
    && cfg.zramSwap.algorithm == "zstd"
  ) minimalConfig;

  # LocalSend's port opens on the desktop.
  eval-omarchy-firewall-desktop =
    testNixOSCheck "omarchy-firewall-desktop"
      (cfg: builtins.elem 53317 cfg.networking.firewall.allowedTCPPorts)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # snapshots on a btrfs host: snapper is configured for the root subvolume.
  eval-omarchy-snapshots-btrfs =
    testNixOSCheck "omarchy-snapshots-btrfs"
      (cfg: (cfg.services.snapper.configs.root.SUBVOLUME or null) == "/")
      (withTestUser {
        marchyo.snapshots.enable = true;
      });

  # snapshots on a non-btrfs host: no snapper config, warning emitted.
  eval-omarchy-snapshots-nonbtrfs =
    testNixOSCheck "omarchy-snapshots-nonbtrfs"
      (
        cfg:
        (cfg.services.snapper.configs or { }) == { } && lib.any (w: lib.hasInfix "btrfs" w) cfg.warnings
      )
      (withTestUser {
        marchyo.snapshots = {
          enable = true;
          btrfs = false;
        };
      });

  # autoTimezone opt-in turns on the geoclue-based daemon.
  eval-omarchy-autotimezone =
    testNixOSCheck "omarchy-autotimezone" (cfg: cfg.services.automatic-timezoned.enable)
      (withTestUser {
        marchyo.autoTimezone.enable = true;
      });
}
