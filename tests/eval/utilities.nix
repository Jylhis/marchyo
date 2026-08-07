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
  inherit (helpers) withTestUser hyprHasBind hyprEntriesText;

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

  binds = hm: hm.wayland.windowManager.hyprland.settings.bind or [ ];
  hasBind = hm: hyprHasBind (binds hm);
  # Substring search over every rendered bind, for "no bind mentions X" checks.
  hasBindText = hm: s: lib.hasInfix s (hyprEntriesText (binds hm));
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
        hasBind hm "SUPER + CTRL + R" "-e marchyo reminder set"
        && hasBind hm "SUPER + CTRL + ALT + R" "Show reminders"
        && hasBind hm "SUPER + CTRL + SHIFT + R" "marchyo reminder clear"
        && hasBind hm "SUPER + CTRL + ALT + T" "marchyo info datetime"
        && hasBind hm "SUPER + CTRL + ALT + B" "marchyo info battery"
        && hasBind hm "SUPER + CTRL + period" "Transcode media"
        # Share stays deliberately unbound (CLI/central-menu entry); the
        # scripts were absorbed into the CLI, whose tools are installed.
        && hasPackage hm "gum"
        && !(hasBindText hm "marchyo share")
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
        !(hasBindText hm "marchyo reminder") && hasBind hm "SUPER + CTRL + ALT + T" "marchyo info datetime"
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
        !(hasBindText hm "marchyo info datetime")
        && !(hasBindText hm "marchyo transcode")
        && hasBind hm "SUPER + CTRL + R" "Set reminder"
      then
        "pass"
      else
        throw "FAIL: utilities disabled but notify/transcode/share remain (or the reminder binds vanished too)"
    );
}
