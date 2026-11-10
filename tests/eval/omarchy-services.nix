_: {
  refs = {
    # avahi / firewall / zram are on by default (mkDefault) on any host.
    minimal.eval-omarchy-service-defaults =
      cfg:
      cfg.services.avahi.enable
      && cfg.services.avahi.nssmdns4
      && cfg.networking.firewall.enable
      && cfg.zramSwap.enable
      && cfg.zramSwap.algorithm == "zstd";

    # LocalSend's port opens on the desktop (via modules/nixos/localsend.nix;
    # the sub-toggle is exercised in tests/eval/localsend.nix).
    desktop.eval-omarchy-firewall-desktop =
      cfg: builtins.elem 53317 cfg.networking.firewall.allowedTCPPorts;

    # autoTimezone opt-in turns on the geoclue-based daemon.
    headless-tweaks.eval-omarchy-autotimezone = cfg: cfg.services.automatic-timezoned.enable;
  };

  refConfig.headless-tweaks.marchyo.autoTimezone.enable = true;
}
