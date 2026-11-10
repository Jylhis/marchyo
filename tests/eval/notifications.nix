{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind expect;
in
{
  refs = {
    desktop-tweaks-2 = {
      # Rules are accepted and the shell still evaluates with them threaded into the
      # marchyo-shell override (a broken thread would throw during eval).
      eval-notifications-rules-accepted =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        if
          (lib.length cfg.marchyo.notifications.rules == 2) && (hm.systemd.user.services ? marchyo-shell)
        then
          true
        else
          "notification rules set but the shell did not evaluate with them";

      # Deck, code and DND-pass options default on and thread into the shell.
      eval-notifications-stack-options =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        if
          cfg.marchyo.notifications.passApps == [
            "marchyo"
            "Calendar"
          ]
          && (hm.systemd.user.services ? marchyo-shell)
        then
          true
        else
          "notification passApps did not thread through or the shell did not evaluate";
    };

    desktop = {
      # Default: no rules.
      eval-notifications-rules-empty-by-default =
        cfg:
        if cfg.marchyo.notifications.rules == [ ] then
          true
        else
          "marchyo.notifications.rules is not empty by default";

      # With the shell on, SUPER+N toggles the notification centre panel through
      # the shell's panel.notifications global shortcut.
      eval-notifications-centre-bind =
        c:
        let
          binds = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
        in
        if hyprHasBind binds "SUPER + N" "hl.dsp.global(\"marchyo:panel.notifications\")" then
          true
        else
          "SUPER+N should dispatch the panel.notifications global shortcut when the shell is on";

      # The session unit that announces NEWS and the first-login welcome exists with
      # the shell on, runs both commands, and is absent without the shell.
      eval-notifications-session-notices =
        c:
        let
          svc = c.home-manager.users.testuser.systemd.user.services.marchyo-session-notices;
          cmds = lib.concatStringsSep "\n" svc.Service.ExecStart;
        in
        if
          lib.hasInfix "whats-new --notify" cmds
          && lib.hasInfix "setup --welcome" cmds
          && svc.Install.WantedBy == [ "graphical-session.target" ]
        then
          true
        else
          "marchyo-session-notices unit wrong: ${builtins.toJSON svc}";
    };

    # The defaults half of eval-notifications-stack-options: deck, code and
    # DND-pass options default on.
    desktop.eval-notifications-stack-options-defaults =
      c:
      let
        dflt = c.marchyo.notifications;
      in
      expect (
        dflt.stackBySender && dflt.detectCodes && dflt.passApps == [ "marchyo" ]
      ) "notification stack options have the wrong defaults";

    # ... and the session-notices unit is absent without the shell.
    desktop-shell-off.eval-notifications-session-notices-shell-off =
      c:
      expect (
        !(c.home-manager.users.testuser.systemd.user.services ? marchyo-session-notices)
      ) "marchyo-session-notices exists with the shell off";
  };

  refConfig.desktop-tweaks-2.marchyo.notifications = {
    rules = [
      {
        appName = "Slack";
        bypassDnd = true;
      }
      {
        desktopEntry = "org.telegram.desktop";
        saveHistory = false;
      }
    ];
    passApps = [
      "marchyo"
      "Calendar"
    ];
  };
}
