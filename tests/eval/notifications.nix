# Per-sender notification rules + the notification-centre keybind. The rules
# option is accepted and threaded into the shell only when marchyo.shell is on;
# SUPER+SHIFT+ALT+comma summons the notification centre over IPC in that case.
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

  # With the shell on, SUPER+N toggles the notification centre panel through
  # the shell's panel.notifications global shortcut.
  eval-notifications-centre-bind =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-notifications-centre-bind" (
      if hyprHasBind binds "SUPER + N" "hl.dsp.global(\"marchyo:panel.notifications\")" then
        "pass"
      else
        throw "FAIL: SUPER+N should dispatch the panel.notifications global shortcut when the shell is on"
    );

  # Deck, code and DND-pass options default on and thread into the shell.
  eval-notifications-stack-options =
    let
      cfg =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.notifications.passApps = [
            "marchyo"
            "Calendar"
          ];
        }).config;
      hm = cfg.home-manager.users.testuser;
      dflt = (evalWith { }).config.marchyo.notifications;
    in
    pkgs.writeText "eval-notifications-stack-options" (
      if
        dflt.stackBySender
        && dflt.detectCodes
        && dflt.passApps == [ "marchyo" ]
        && (hm.systemd.user.services ? marchyo-shell)
      then
        "pass"
      else
        throw "FAIL: notification stack options wrong defaults or shell did not evaluate"
    );

  # The session unit that announces NEWS and the first-login welcome exists with
  # the shell on, runs both commands, and is absent without the shell.
  eval-notifications-session-notices =
    let
      svc =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.systemd.user.services.marchyo-session-notices;
      off =
        (evalWith { marchyo.shell.enable = false; })
        .config.home-manager.users.testuser.systemd.user.services
          ? marchyo-session-notices;
      cmds = lib.concatStringsSep "\n" svc.Service.ExecStart;
    in
    pkgs.writeText "eval-notifications-session-notices" (
      if
        !off
        && lib.hasInfix "whats-new --notify" cmds
        && lib.hasInfix "setup --welcome" cmds
        && svc.Install.WantedBy == [ "graphical-session.target" ]
      then
        "pass"
      else
        throw "FAIL: marchyo-session-notices unit wrong: ${builtins.toJSON svc}"
    );
}
