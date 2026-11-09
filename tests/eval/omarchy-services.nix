{ helpers, ... }:
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

  # LocalSend's port opens on the desktop (via modules/nixos/localsend.nix;
  # the sub-toggle is exercised in tests/eval/localsend.nix).
  eval-omarchy-firewall-desktop =
    testNixOSCheck "omarchy-firewall-desktop"
      (cfg: builtins.elem 53317 cfg.networking.firewall.allowedTCPPorts)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # autoTimezone opt-in turns on the geoclue-based daemon.
  eval-omarchy-autotimezone =
    testNixOSCheck "omarchy-autotimezone" (cfg: cfg.services.automatic-timezoned.enable)
      (withTestUser {
        marchyo.autoTimezone.enable = true;
      });
}
