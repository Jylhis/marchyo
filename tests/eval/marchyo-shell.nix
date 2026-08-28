# Quickshell shell: the marchyo-shell user service appears only when
# marchyo.shell.enable is set, and stays absent under a plain desktop (it does not
# cascade from desktop.enable). The shell and waybar are mutually exclusive — when
# the shell is on, waybar stands down — so the two bars never both run.
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

  # Cutover: with the shell on, waybar must stand down so the two bars are never
  # both active.
  eval-marchyo-shell-disables-waybar =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disables-waybar" (
      if !hm.programs.waybar.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell.enable = true but waybar is still enabled (both bars would run)"
    );

  # Plain desktop (shell off): waybar is the bar, so it must be enabled.
  eval-marchyo-shell-off-keeps-waybar =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-waybar" (
      if hm.programs.waybar.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but waybar is not enabled under a plain desktop"
    );

  # OSD cutover: the shell provides its own OSD, so with the shell on the SwayOSD
  # server must stand down — the two OSDs never both run.
  eval-marchyo-shell-disables-swayosd =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disables-swayosd" (
      if !(hm.systemd.user.services ? swayosd) then
        "pass"
      else
        throw "FAIL: marchyo.shell.enable = true but the swayosd server is still defined (both OSDs would run)"
    );

  # Plain desktop (shell off): SwayOSD is the OSD, so its server must be present.
  eval-marchyo-shell-off-keeps-swayosd =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-swayosd" (
      if (hm.systemd.user.services ? swayosd) then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but the swayosd server is missing under a plain desktop"
    );
}
