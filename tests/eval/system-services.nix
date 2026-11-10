# Global, headless-safe services that should be on even without the desktop:
# firmware updates (fwupd) and crash capture (systemd-coredump).
_: {
  refs.headless = {
    eval-fwupd-headless = cfg: cfg.services.fwupd.enable;
    eval-coredump-headless = cfg: cfg.systemd.coredump.enable;
  };
}
