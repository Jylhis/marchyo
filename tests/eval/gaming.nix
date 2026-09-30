{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasPkg = name: cfg: builtins.any (p: lib.getName p == name) cfg.environment.systemPackages;
  steamOn = cfg: cfg.programs.steam.enable;
in
{
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
# Steam is x86_64-only (and its module forces 32-bit graphics, which nixpkgs
# rejects elsewhere), so the bundle only materialises on the x86 CI leg.
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
  # Desktop + opt-in: Steam is enabled and the launchers ship.
  eval-gaming-enabled =
    testNixOSCheck "gaming-enabled"
      (cfg: steamOn cfg && hasPkg "lutris" cfg && hasPkg "heroic" cfg && cfg.programs.gamemode.enable)
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.gaming.enable = true;
      });
}
// lib.optionalAttrs (!pkgs.stdenv.hostPlatform.isx86_64) {
  # Opting in on a non-x86 desktop stays inert instead of failing to evaluate.
  eval-gaming-non-x86-inert =
    testNixOSCheck "gaming-non-x86-inert" (cfg: !(steamOn cfg) && !(hasPkg "lutris" cfg))
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.gaming.enable = true;
      });
}
