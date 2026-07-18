{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  hmOf = eval: eval.config.home-manager.users.testuser;
  hasPkg = hm: n: lib.any (p: (p.name or "") == n) hm.home.packages;
  listeners = hm: hm.services.hypridle.settings.listener or [ ];
  hasListener =
    hm: lib.any (l: (l.on-timeout or "") == "marchyo-screensaver-launch") (listeners hm);
in
{
  # Default-on with desktop: both scripts installed and the hypridle idle
  # listener wired.
  eval-screensaver-enabled =
    let
      hm = hmOf (evalWith { });
    in
    pkgs.writeText "eval-screensaver-enabled" (
      if hasPkg hm "marchyo-screensaver" && hasPkg hm "marchyo-screensaver-launch" && hasListener hm then
        "pass"
      else
        throw "FAIL: screensaver default-on with desktop but its scripts or hypridle listener are missing"
    );

  # Opt-out: no screensaver scripts and no idle listener, while the other
  # hypridle listeners (dim/lock/dpms) stay in place.
  eval-screensaver-disabled =
    let
      hm = hmOf (evalWith { marchyo.screensaver.enable = false; });
    in
    pkgs.writeText "eval-screensaver-disabled" (
      if !(hasPkg hm "marchyo-screensaver") && !(hasListener hm) && listeners hm != [ ] then
        "pass"
      else
        throw "FAIL: screensaver disabled but its script or hypridle listener is still present"
    );
}
