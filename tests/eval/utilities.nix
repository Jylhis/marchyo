# Omarchy-parity trigger utilities (modules/home/utilities.nix): reminders,
# quick-info notifications, transcode + share. Mirrors the webapps.nix test
# pattern to assert the contributed Hyprland binds, not just clean evaluation.
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

  binds = hm: hm.wayland.windowManager.hyprland.settings.bindd or [ ];
  hasBind = hm: s: lib.any (b: lib.hasInfix s b) (binds hm);
  hasPackage = hm: n: lib.any (p: lib.getName p == n) hm.home.packages;
in
{
  # Desktop cascade: both toggles default on, so every script and bind lands.
  eval-utilities-enabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-utilities-enabled" (
      if
        hasBind hm "SUPER CTRL, R, Set reminder, exec, $terminal --class=org.omarchy.terminal -e marchyo reminder set"
        && hasBind hm "SUPER CTRL ALT, R, Show reminders, exec, "
        && hasBind hm "SUPER CTRL SHIFT, R, Clear reminders, exec, marchyo reminder clear"
        && hasBind hm "SUPER CTRL ALT, T, Show date and time, exec, marchyo info datetime"
        && hasBind hm "SUPER CTRL ALT, B, Show battery status, exec, marchyo info battery"
        && hasBind hm "SUPER CTRL, period, Transcode media, exec, "
        # Share stays deliberately unbound (CLI/central-menu entry); the
        # scripts were absorbed into the CLI, whose tools are installed.
        && hasPackage hm "gum"
        && !(hasBind hm "marchyo share")
      then
        "pass"
      else
        throw "FAIL: desktop enabled but a trigger-utility bind or the CLI tool closure is missing, or share leaked a bind"
    );

  # Reminders opt-out drops only the reminder binds; the rest stays.
  eval-utilities-reminders-disabled =
    let
      hm = (evalWith { marchyo.reminders.enable = false; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-utilities-reminders-disabled" (
      if
        !(hasBind hm "marchyo reminder")
        && hasBind hm "SUPER CTRL ALT, T, Show date and time, exec, marchyo info datetime"
      then
        "pass"
      else
        throw "FAIL: reminders disabled but reminder binds/packages remain (or the utility binds vanished too)"
    );

  # Utilities opt-out drops notify/transcode/share; reminders stay.
  eval-utilities-disabled =
    let
      hm = (evalWith { marchyo.utilities.enable = false; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-utilities-disabled" (
      if
        !(hasBind hm "marchyo info datetime")
        && !(hasBind hm "marchyo transcode")
        && hasBind hm "SUPER CTRL, R, Set reminder, exec, "
      then
        "pass"
      else
        throw "FAIL: utilities disabled but notify/transcode/share remain (or the reminder binds vanished too)"
    );
}
