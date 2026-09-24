# Shell appearance scale axes (marchyo.theme.appearance): the options are
# accepted, default to neutral values, and the shell still evaluates with them
# threaded into the marchyo-shell override.
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
in
{
  eval-appearance-defaults-neutral =
    let
      a = (evalWith { }).config.marchyo.theme.appearance;
    in
    pkgs.writeText "eval-appearance-defaults-neutral" (
      if
        a.cornerRadiusScale == 1.0 && a.uiScale == 1.0 && a.animationSpeed == 1.0 && (!a.highContrast)
      then
        "pass"
      else
        throw "FAIL: marchyo.theme.appearance defaults are not neutral"
    );

  # Non-neutral axes are accepted and the shell evaluates with them.
  eval-appearance-threaded =
    let
      cfg =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.theme.appearance = {
            cornerRadiusScale = 0.0;
            uiScale = 1.5;
            animationSpeed = 2.0;
            highContrast = true;
          };
        }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-appearance-threaded" (
      if (hm.systemd.user.services ? marchyo-shell) && cfg.marchyo.theme.appearance.highContrast then
        "pass"
      else
        throw "FAIL: appearance axes set but the shell did not evaluate with them"
    );
}
