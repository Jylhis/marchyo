{
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasPkg = name: cfg: builtins.any (p: lib.getName p == name) cfg.environment.systemPackages;
  steamOn = cfg: cfg.programs.steam.enable;
in
{
  # Desktop + opt-in: Steam is enabled and the launchers ship.
  eval-gaming-enabled =
    testNixOSCheck "gaming-enabled"
      (cfg: steamOn cfg && hasPkg "lutris" cfg && hasPkg "heroic" cfg && cfg.programs.gamemode.enable)
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.gaming.enable = true;
      });

  # Desktop alone does NOT pull in gaming (not auto-cascaded).
  eval-gaming-desktop-only =
    testNixOSCheck "gaming-desktop-only" (cfg: !(steamOn cfg) && !(hasPkg "lutris" cfg))
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # gaming.enable without the desktop is inert.
  eval-gaming-headless = testNixOSCheck "gaming-headless" (cfg: !(steamOn cfg)) (withTestUser {
    marchyo.gaming.enable = true;
  });
}
