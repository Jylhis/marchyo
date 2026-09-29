# Global, headless-safe services that should be on even without the desktop:
# firmware updates (fwupd) and crash capture (systemd-coredump).
{
  helpers,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  eval-fwupd-headless = testNixOSCheck "fwupd-headless" (cfg: cfg.services.fwupd.enable) (
    withTestUser { }
  );

  eval-coredump-headless = testNixOSCheck "coredump-headless" (cfg: cfg.systemd.coredump.enable) (
    withTestUser { }
  );
}
