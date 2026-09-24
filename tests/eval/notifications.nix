# Per-sender notification rules + the notification-centre keybind. The rules
# option is accepted and threaded into the shell only when marchyo.shell is on;
# SUPER+N summons the notification centre over IPC in that case.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind;

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
  # Rules are accepted and the shell still evaluates with them threaded into the
  # marchyo-shell override (a broken thread would throw during eval).
  eval-notifications-rules-accepted =
    let
      cfg =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.notifications.rules = [
            {
              appName = "Slack";
              bypassDnd = true;
            }
            {
              desktopEntry = "org.telegram.desktop";
              saveHistory = false;
            }
          ];
        }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-notifications-rules-accepted" (
      if
        (lib.length cfg.marchyo.notifications.rules == 2) && (hm.systemd.user.services ? marchyo-shell)
      then
        "pass"
      else
        throw "FAIL: notification rules set but the shell did not evaluate with them"
    );

  # Default: no rules.
  eval-notifications-rules-empty-by-default =
    let
      cfg = (evalWith { }).config;
    in
    pkgs.writeText "eval-notifications-rules-empty-by-default" (
      if cfg.marchyo.notifications.rules == [ ] then
        "pass"
      else
        throw "FAIL: marchyo.notifications.rules is not empty by default"
    );

  # With the shell on, SUPER+N opens the notification centre over IPC.
  eval-notifications-centre-bind =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-notifications-centre-bind" (
      if hyprHasBind binds "SUPER + N" "toggleNotifications" then
        "pass"
      else
        throw "FAIL: SUPER+N should summon the notification centre over IPC when the shell is on"
    );
}
