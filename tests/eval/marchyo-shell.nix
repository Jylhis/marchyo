# Quickshell shell: marchyo.shell.enable cascades from desktop.enable, so the
# marchyo-shell user service appears on a plain desktop and stays absent without
# one. The lock and polkit surfaces are mutually exclusive with their discrete
# counterparts (hyprlock, hyprpolkitagent), which stay as the
# marchyo.shell.enable = false fallback; the desktop-shell-off predicates pin
# that fallback.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind hyprEntryText expect;
  bindsOf = c: c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
  hasR = binds: lib.any (e: (e._args or [ ]) != [ ] && builtins.head e._args == "SUPER + R") binds;
in
{
  refs = {
    desktop = {
      # shell.enable on: the user service is defined and launches marchyo-shell.
      eval-marchyo-shell-enabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          (hm.systemd.user.services ? marchyo-shell)
          && lib.hasInfix "marchyo-shell" (toString hm.systemd.user.services.marchyo-shell.Service.ExecStart)
        then
          true
        else
          "marchyo.shell.enable = true but the marchyo-shell user service is missing or does not launch marchyo-shell";

      # The shell is the default with the desktop: a plain desktop enables it and
      # runs the user service; without the desktop it stays off and absent.
      eval-marchyo-shell-default-with-desktop =
        c:
        let
          desktop = c;
          desktopHm = desktop.home-manager.users.testuser;
        in
        if !desktop.marchyo.shell.enable then
          "marchyo.desktop.enable = true should enable marchyo.shell by default"
        else if !(desktopHm.systemd.user.services ? marchyo-shell) then
          "the marchyo-shell user service is missing under a plain desktop"
        else
          true;

      # Phase 4 lock cutover: with the shell on, hyprlock stands down (the shell's
      # WlSessionLock owns the lock).
      eval-marchyo-shell-disables-hyprlock =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if !hm.programs.hyprlock.enable then
          true
        else
          "marchyo.shell.enable = true but hyprlock is still enabled (two lockers)";

      # SUPER+L reaches the running shell through `marchyo shell lock` when it is
      # on; hyprlock when off.
      eval-marchyo-shell-lock-bind =
        c:
        let
          bind = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
        in
        if hyprHasBind bind "SUPER + L" "marchyo shell lock" then
          true
        else
          "SUPER+L should run 'marchyo shell lock' when the shell is enabled";

      # SUPER+grave summons the window overview through the shell's `overview`
      # global shortcut when the shell is on, and is the only bind on that chord; with the shell
      # off there is no overview and no bind.
      eval-marchyo-shell-overview-bind =
        c:
        let
          bindsFor = cfg: cfg.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
          on = bindsFor c;
          onChord = lib.filter (e: (e._args or [ ]) != [ ] && builtins.head e._args == "SUPER + grave") on;
        in
        if !(hyprHasBind on "SUPER + grave" "hl.dsp.global(\"marchyo:overview\")") then
          "SUPER+grave should dispatch the overview global shortcut when the shell is on"
        else if lib.length onChord != 1 then
          "SUPER+grave should carry exactly one bind, found ${toString (lib.length onChord)}"
        else
          true;

      # hypridle stays the idle authority, but its lock points (general.lock_cmd,
      # before_sleep_cmd, the 300s listener) run `marchyo shell lock` when it is on.
      eval-marchyo-shell-hypridle-locks-via-cli =
        c:
        let
          hm = c.home-manager.users.testuser;
          general = hm.services.hypridle.settings.general;
          # toJSON, not toString: the listeners are attrsets, which toString
          # cannot coerce.
          listenersText = builtins.toJSON hm.services.hypridle.settings.listener;
          ok =
            lib.hasInfix "marchyo shell lock" (general.lock_cmd or "")
            && lib.hasInfix "marchyo shell lock" (general.before_sleep_cmd or "")
            && lib.hasInfix "marchyo shell lock" listenersText
            && !lib.hasInfix "marchyo-shell ipc" (builtins.toJSON hm.services.hypridle.settings);
        in
        if ok then
          true
        else
          "hypridle lock commands do not run 'marchyo shell lock' when marchyo.shell is on";

      # The NixOS half of the hyprlock cutover: programs.hyprlock and its PAM
      # service must stand down too, or a stray hyprlock install remains.
      eval-marchyo-shell-nixos-hyprlock-stands-down =
        c:

        if !c.programs.hyprlock.enable && !(c.security.pam.services ? hyprlock) then
          true
        else
          "marchyo.shell.enable = true but NixOS still enables hyprlock or its PAM service";

      # With the shell on, the launcher binds summon the in-shell launcher through
      # its global shortcuts.
      eval-marchyo-shell-launcher-binds =
        c:
        let
          binds = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
        in
        if !(hyprHasBind binds "SUPER + R" "hl.dsp.global(\"marchyo:launcher.apps\")") then
          "SUPER+R should summon the in-shell launcher when the shell is on"
        else if !(hyprHasBind binds "SUPER + period" "hl.dsp.global(\"marchyo:launcher.emoji\")") then
          "SUPER+period should summon the in-shell emoji picker when the shell is on"
        else if !(hyprHasBind binds "SUPER + CTRL + T" "hl.dsp.global(\"marchyo:panel.themes\")") then
          "SUPER+CTRL+T should open the theme picker when the shell is on"
        else if !(hyprHasBind binds "SUPER + period" "Emoji picker") then
          "SUPER+period should keep its 'Emoji picker' description (hyprland.nix test depends on it)"
        else if !(hyprHasBind binds "SUPER + CTRL + V" "hl.dsp.global(\"marchyo:launcher.clipboard\")") then
          "SUPER+Ctrl+V should summon the in-shell clipboard history when the shell is on"
        else
          true;

      # With the shell on, the media keys run the `marchyo volume` / `brightness`
      # verbs (the shell OSD shows the level) and the panel and bar binds dispatch
      # the shell's global shortcuts.
      eval-marchyo-shell-media-and-panel-verbs =
        c:
        let
          binds = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
        in
        if !(hyprHasBind binds "XF86AudioRaiseVolume" "marchyo volume up") then
          "XF86AudioRaiseVolume should run 'marchyo volume up' when the shell is on"
        else if !(hyprHasBind binds "XF86AudioMicMute" "marchyo volume mute --mic") then
          "XF86AudioMicMute should run 'marchyo volume mute --mic' when the shell is on"
        else if !(hyprHasBind binds "XF86MonBrightnessUp" "marchyo brightness up") then
          "XF86MonBrightnessUp should run 'marchyo brightness up' when the shell is on"
        else if !(hyprHasBind binds "SUPER + SHIFT + V" "hl.dsp.global(\"marchyo:panel.audio\")") then
          "SUPER+SHIFT+V should dispatch the panel.audio global shortcut"
        else if
          !(hyprHasBind binds "SUPER + SHIFT + Q" "hl.dsp.global(\"marchyo:panel.controlcenter\")")
        then
          "SUPER+SHIFT+Q should dispatch the panel.controlcenter global shortcut"
        else if !(hyprHasBind binds "SUPER + SHIFT + SPACE" "hl.dsp.global(\"marchyo:bar\")") then
          "SUPER+SHIFT+SPACE should dispatch the bar global shortcut when the shell is on"
        else
          true;

      # The notification binds reach the shell through its global shortcuts when it
      # owns notifications (DND, dismiss-all), never through raw IPC.
      eval-marchyo-shell-notification-binds =
        c:
        let
          binds = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
        in
        if !(hyprHasBind binds "SUPER + CTRL + comma" "hl.dsp.global(\"marchyo:dnd\")") then
          "SUPER+CTRL+comma should dispatch dnd when the shell is on"
        else if
          !(hyprHasBind binds "SUPER + CTRL + SHIFT + comma"
            "hl.dsp.global(\"marchyo:notifications.dismissAll\")"
          )
        then
          "SUPER+CTRL+SHIFT+comma should dispatch notifications.dismissAll when the shell is on"
        else if
          !(hyprHasBind binds "SUPER + ALT + comma" "hl.dsp.global(\"marchyo:notifications.keyboard\")")
        then
          "SUPER+ALT+comma should dispatch notifications.keyboard when the shell is on"
        else if lib.any (e: lib.hasInfix "marchyo-shell ipc" (hyprEntryText e)) binds then
          "a Hyprland bind still calls marchyo-shell ipc directly"
        else
          true;

      # Polkit cutover: the shell registers the session's polkit agent, and a
      # session holds one, so hyprpolkitagent stands down with the shell on.
      eval-marchyo-shell-disables-hyprpolkitagent =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if hm.services.hyprpolkitagent.enable || (hm.systemd.user.services ? hyprpolkitagent) then
          "marchyo.shell.enable = true but hyprpolkitagent is still enabled (two polkit agents)"
        else
          true;
    };

    desktop-shell-off = {
      # The bar, notification and media-key surfaces exist only in the shell. With
      # the shell off their binds are absent (no dead binds) and the media keys
      # fall back to silent wpctl/brightnessctl.
      eval-marchyo-shell-off-no-shell-binds =
        c:
        let
          binds = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
          chords = map (e: builtins.head e._args) (lib.filter (e: (e._args or [ ]) != [ ]) binds);
          shellOnly = [
            "SUPER + SHIFT + SPACE"
            "SUPER + comma"
            "SUPER + ALT + comma"
            "SUPER + CTRL + comma"
            "SUPER + CTRL + ALT + comma"
            "SUPER + CTRL + SHIFT + comma"
            "SUPER + N"
            "SUPER + SHIFT + B"
            "SUPER + CTRL + D"
            "SUPER + SHIFT + Q"
          ];
          dead = lib.filter (c: lib.elem c chords) shellOnly;
        in
        if dead != [ ] then
          "marchyo.shell is off but these shell-only chords are still bound: ${lib.concatStringsSep ", " dead}"
        else if !(hyprHasBind binds "XF86AudioRaiseVolume" "wpctl set-volume") then
          "marchyo.shell is off but XF86AudioRaiseVolume does not run wpctl"
        else if !(hyprHasBind binds "XF86MonBrightnessUp" "brightnessctl") then
          "marchyo.shell is off but XF86MonBrightnessUp does not run brightnessctl"
        else
          true;

      eval-marchyo-shell-off-keeps-hyprlock =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if hm.programs.hyprlock.enable then
          true
        else
          "marchyo.shell is off but hyprlock is missing on a desktop";

      eval-marchyo-shell-off-keeps-hyprlock-bind =
        c:
        let
          bind = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
        in
        if hyprHasBind bind "SUPER + L" "hyprlock" then
          true
        else
          "marchyo.shell is off but SUPER+L no longer execs hyprlock";

      eval-marchyo-shell-off-hypridle-keeps-loginctl =
        c:
        let
          hm = c.home-manager.users.testuser;
          listenersText = builtins.toJSON hm.services.hypridle.settings.listener;
        in
        if
          lib.hasInfix "loginctl lock-session" listenersText && !lib.hasInfix "shell lock" listenersText
        then
          true
        else
          "hypridle idle-lock listener changed although marchyo.shell is off";

      eval-marchyo-shell-off-nixos-keeps-hyprlock =
        c:

        if c.programs.hyprlock.enable then
          true
        else
          "marchyo.shell is off but NixOS hyprlock is missing on a desktop";

      # The launcher binds need both the shell and marchyo.launcher.enable; without
      # either, Super+R is unbound rather than a dead bind.
      eval-marchyo-shell-launcher-binds-gated =
        c:
        let
          bindsFor = cfg: cfg.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
          hasR = binds: lib.any (e: (e._args or [ ]) != [ ] && builtins.head e._args == "SUPER + R") binds;
        in
        expect (!hasR (bindsFor c)) "marchyo.shell is off but SUPER+R is still bound";

      # Desktop with the shell off (the fallback): hyprpolkitagent is the polkit agent.
      eval-marchyo-shell-off-keeps-hyprpolkitagent =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if hm.services.hyprpolkitagent.enable && (hm.systemd.user.services ? hyprpolkitagent) then
          true
        else
          "marchyo.shell is off but hyprpolkitagent is not enabled on a desktop";
    };

    desktop-tweaks-2 = {
      # marchyo.cli.enable = false keeps the shell binds and idle locking working:
      # the binds dispatch global shortcuts, which need no CLI, and idle locking
      # runs the CLI by store path instead of the (absent) `marchyo` on PATH.
      eval-marchyo-shell-verbs-without-cli =
        c:
        let
          hm = c.home-manager.users.testuser;
          binds = hm.wayland.windowManager.hyprland.settings.bind;
          general = hm.services.hypridle.settings.general;
        in
        if !(hyprHasBind binds "SUPER + SHIFT + V" "hl.dsp.global(\"marchyo:panel.audio\")") then
          "with marchyo.cli.enable = false the panel binds should still dispatch global shortcuts"
        else if !(hyprHasBind binds "SUPER + CTRL + comma" "hl.dsp.global(\"marchyo:dnd\")") then
          "with marchyo.cli.enable = false the DND bind should still dispatch its global shortcut"
        else if !(hyprHasBind binds "SUPER + L" "/bin/marchyo shell lock") then
          "with marchyo.cli.enable = false SUPER+L should lock through the CLI by store path"
        else if
          !(lib.hasInfix "/bin/marchyo shell lock" (general.lock_cmd or ""))
          || !(lib.hasInfix "/bin/marchyo shell lock" (general.before_sleep_cmd or ""))
        then
          "with marchyo.cli.enable = false hypridle should lock through the CLI by store path"
        else
          true;
    };

    desktop-tweaks = {
      # Auto video caffeine: the shell's systemd-inhibit --what=idle only reaches
      # hypridle while hypridle honours logind inhibitors, and the
      # caffeine.autoVideo opt-out must reach the shell.json the shell reads.
      eval-marchyo-shell-caffeine-auto-video =
        c:
        let
          hm = c.home-manager.users.testuser;
          shellJson = builtins.fromJSON hm.xdg.configFile."marchyo/shell.json".text;
        in
        if (hm.services.hypridle.settings.general.ignore_systemd_inhibit or false) then
          "hypridle ignores systemd idle inhibitors, so the shell's auto video caffeine cannot reach it"
        else if (shellJson.caffeine.autoVideo or true) != false then
          "marchyo.shell.settings.caffeine.autoVideo = false did not reach shell.json"
        else
          true;
    };

    # The other sides of the tests above.
    # Without the desktop the shell stays off and absent.
    headless.eval-marchyo-shell-default-with-desktop-headless =
      c:
      if c.marchyo.shell.enable then
        "marchyo.shell is on without marchyo.desktop.enable"
      else if c.home-manager.users.testuser.systemd.user.services ? marchyo-shell then
        "the marchyo-shell user service is present without marchyo.desktop.enable"
      else
        true;

    # With the shell off there is no overview and no marchyo global-shortcut bind.
    desktop-shell-off.eval-marchyo-shell-overview-bind-shell-off =
      c:
      expect (
        !(lib.any (e: lib.hasInfix "marchyo:" (hyprEntryText e)) (bindsOf c))
      ) "marchyo.shell is off but a bind still dispatches a marchyo global shortcut";

    # marchyo.launcher.enable = false (desktop-off) unbinds Super+R too.
    desktop-off.eval-marchyo-shell-launcher-binds-gated-launcher-off =
      c: expect (!hasR (bindsOf c)) "marchyo.launcher.enable = false but SUPER+R is still bound";
  };

  # desktop-tweaks: the caffeine.autoVideo opt-out (with the rest of the
  # shell-settings fixture, tests/eval/shell-settings.nix); desktop-off:
  # marchyo.launcher.enable = false.
  refConfig.desktop-off.marchyo.launcher.enable = false;
}
