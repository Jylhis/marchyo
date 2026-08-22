# Phase 0 Quickshell shell: the marchyo-shell user service appears only when
# marchyo.shell.enable is set, and stays absent under a plain desktop (it does
# not cascade from desktop.enable, so it never collides with the waybar stack).
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
  # shell.enable on: the user service is defined and launches marchyo-shell.
  eval-marchyo-shell-enabled =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-enabled" (
      if
        (hm.systemd.user.services ? marchyo-shell)
        && lib.hasInfix "marchyo-shell" (toString hm.systemd.user.services.marchyo-shell.Service.ExecStart)
      then
        "pass"
      else
        throw "FAIL: marchyo.shell.enable = true but the marchyo-shell user service is missing or does not launch marchyo-shell"
    );

  # Default desktop: opt-in only, so the service must not appear (no collision
  # with the discrete waybar/mako/swayosd stack).
  eval-marchyo-shell-disabled-by-default =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disabled-by-default" (
      if !(hm.systemd.user.services ? marchyo-shell) then
        "pass"
      else
        throw "FAIL: marchyo.shell is off by default but the marchyo-shell user service is present under a plain desktop"
    );
}
