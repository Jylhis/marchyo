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
  hasListener = hm: lib.any (l: (l.on-timeout or "") == "marchyo-screensaver-launch") (listeners hm);
  hasRule =
    hm:
    lib.any (r: lib.hasInfix "org.omarchy.screensaver" r) (
      hm.wayland.windowManager.hyprland.settings.windowrule or [ ]
    );
in
{
  # Default-on with desktop: both scripts installed, the hypridle idle
  # listener wired, and the fullscreen window rule contributed.
  eval-screensaver-enabled =
    let
      hm = hmOf (evalWith { });
    in
    pkgs.writeText "eval-screensaver-enabled" (
      if
        hasPkg hm "marchyo-screensaver"
        && hasPkg hm "marchyo-screensaver-launch"
        && hasListener hm
        && hasRule hm
      then
        "pass"
      else
        throw "FAIL: screensaver default-on with desktop but its scripts, hypridle listener, or window rule are missing"
    );

  # Opt-out: no screensaver scripts and no idle listener, while the other
  # hypridle listeners (dim/lock/dpms) stay in place.
  eval-screensaver-disabled =
    let
      hm = hmOf (evalWith {
        marchyo.screensaver.enable = false;
      });
    in
    pkgs.writeText "eval-screensaver-disabled" (
      if
        !(hasPkg hm "marchyo-screensaver") && !(hasListener hm) && !(hasRule hm) && listeners hm != [ ]
      then
        "pass"
      else
        throw "FAIL: screensaver disabled but its script, window rule, or hypridle listener is still present"
    );
}
