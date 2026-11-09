# Quickshell shell: marchyo.shell.enable cascades from desktop.enable, so the
# marchyo-shell user service appears on a plain desktop and stays absent without
# one. The lock and polkit surfaces are mutually exclusive with their discrete
# counterparts (hyprlock, hyprpolkitagent), which stay as the
# marchyo.shell.enable = false fallback; the `off` tests pin that fallback.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntryText;

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

  shellOff = {
    marchyo.shell.enable = false;
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

  # The shell is the default with the desktop: a plain desktop enables it and
  # runs the user service; without the desktop it stays off and absent.
  eval-marchyo-shell-default-with-desktop =
    let
      desktop = (evalWith { }).config;
      noDesktop = (evalWith { marchyo.desktop.enable = false; }).config;
      desktopHm = desktop.home-manager.users.testuser;
      noDesktopHm = noDesktop.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-default-with-desktop" (
      if !desktop.marchyo.shell.enable then
        throw "FAIL: marchyo.desktop.enable = true should enable marchyo.shell by default"
      else if !(desktopHm.systemd.user.services ? marchyo-shell) then
        throw "FAIL: the marchyo-shell user service is missing under a plain desktop"
      else if noDesktop.marchyo.shell.enable then
        throw "FAIL: marchyo.shell is on without marchyo.desktop.enable"
      else if noDesktopHm.systemd.user.services ? marchyo-shell then
        throw "FAIL: the marchyo-shell user service is present without marchyo.desktop.enable"
      else
        "pass"
    );

  # The bar, notification and media-key surfaces exist only in the shell. With
  # the shell off their binds are absent (no dead binds) and the media keys
  # fall back to silent wpctl/brightnessctl.
  eval-marchyo-shell-off-no-shell-binds =
    let
      binds =
        (evalWith shellOff).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
      chords = map (e: builtins.head e._args) (lib.filter (e: (e._args or [ ]) != [ ]) binds);
      shellOnly = [
        "SUPER + SHIFT + SPACE"
        "SUPER + comma"
        "SUPER + ALT + comma"
        "SUPER + CTRL + comma"
        "SUPER + CTRL + ALT + comma"
        "SUPER + SHIFT + comma"
        "SUPER + SHIFT + ALT + comma"
        "SUPER + CTRL + P"
        "SUPER + CTRL + D"
        "SUPER + CTRL + O"
      ];
      dead = lib.filter (c: lib.elem c chords) shellOnly;
    in
    pkgs.writeText "eval-marchyo-shell-off-no-shell-binds" (
      if dead != [ ] then
        throw "FAIL: marchyo.shell is off but these shell-only chords are still bound: ${lib.concatStringsSep ", " dead}"
      else if !(hyprHasBind binds "XF86AudioRaiseVolume" "wpctl set-volume") then
        throw "FAIL: marchyo.shell is off but XF86AudioRaiseVolume does not run wpctl"
      else if !(hyprHasBind binds "XF86MonBrightnessUp" "brightnessctl") then
        throw "FAIL: marchyo.shell is off but XF86MonBrightnessUp does not run brightnessctl"
      else
        "pass"
    );

  # Phase 4 lock cutover: with the shell on, hyprlock stands down (the shell's
  # WlSessionLock owns the lock).
  eval-marchyo-shell-disables-hyprlock =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disables-hyprlock" (
      if !hm.programs.hyprlock.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell.enable = true but hyprlock is still enabled (two lockers)"
    );

  eval-marchyo-shell-off-keeps-hyprlock =
    let
      hm = (evalWith shellOff).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-hyprlock" (
      if hm.programs.hyprlock.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but hyprlock is missing on a desktop"
    );

  # SUPER+CTRL+L reaches the running shell through `marchyo shell lock` when it is
  # on; hyprlock when off.
  eval-marchyo-shell-lock-bind =
    let
      bind =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-lock-bind" (
      if hyprHasBind bind "SUPER + CTRL + L" "marchyo shell lock" then
        "pass"
      else
        throw "FAIL: SUPER+CTRL+L should run 'marchyo shell lock' when the shell is enabled"
    );

  eval-marchyo-shell-off-keeps-hyprlock-bind =
    let
      bind =
        (evalWith shellOff).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-hyprlock-bind" (
      if hyprHasBind bind "SUPER + CTRL + L" "hyprlock" then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but SUPER+CTRL+L no longer execs hyprlock"
    );

  # SUPER+CTRL+grave summons the window overview through the shell's `overview`
  # global shortcut when the shell is on, and is the only bind on that chord; with the shell
  # off there is no overview and no bind.
  eval-marchyo-shell-overview-bind =
    let
      bindsFor =
        extra:
        (evalWith extra).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
      on = bindsFor { marchyo.shell.enable = true; };
      off = bindsFor shellOff;
      onChord = lib.filter (
        e: (e._args or [ ]) != [ ] && builtins.head e._args == "SUPER + CTRL + grave"
      ) on;
    in
    pkgs.writeText "eval-marchyo-shell-overview-bind" (
      if !(hyprHasBind on "SUPER + CTRL + grave" "hl.dsp.global(\"marchyo:overview\")") then
        throw "FAIL: SUPER+CTRL+grave should dispatch the overview global shortcut when the shell is on"
      else if lib.length onChord != 1 then
        throw "FAIL: SUPER+CTRL+grave should carry exactly one bind, found ${toString (lib.length onChord)}"
      else if lib.any (e: lib.hasInfix "marchyo:" (hyprEntryText e)) off then
        throw "FAIL: marchyo.shell is off but a bind still dispatches a marchyo global shortcut"
      else
        "pass"
    );

  # hypridle stays the idle authority, but its lock points (general.lock_cmd,
  # before_sleep_cmd, the 300s listener) run `marchyo shell lock` when it is on.
  eval-marchyo-shell-hypridle-locks-via-cli =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
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
    pkgs.writeText "eval-marchyo-shell-hypridle-locks-via-cli" (
      if ok then
        "pass"
      else
        throw "FAIL: hypridle lock commands do not run 'marchyo shell lock' when marchyo.shell is on"
    );

  eval-marchyo-shell-off-hypridle-keeps-loginctl =
    let
      hm = (evalWith shellOff).config.home-manager.users.testuser;
      listenersText = builtins.toJSON hm.services.hypridle.settings.listener;
    in
    pkgs.writeText "eval-marchyo-shell-off-hypridle-keeps-loginctl" (
      if
        lib.hasInfix "loginctl lock-session" listenersText && !lib.hasInfix "shell lock" listenersText
      then
        "pass"
      else
        throw "FAIL: hypridle idle-lock listener changed although marchyo.shell is off"
    );

  # The NixOS half of the hyprlock cutover: programs.hyprlock and its PAM
  # service must stand down too, or a stray hyprlock install remains.
  eval-marchyo-shell-nixos-hyprlock-stands-down =
    let
      c = (evalWith { marchyo.shell.enable = true; }).config;
    in
    pkgs.writeText "eval-marchyo-shell-nixos-hyprlock-stands-down" (
      if !c.programs.hyprlock.enable && !(c.security.pam.services ? hyprlock) then
        "pass"
      else
        throw "FAIL: marchyo.shell.enable = true but NixOS still enables hyprlock or its PAM service"
    );

  eval-marchyo-shell-off-nixos-keeps-hyprlock =
    let
      c = (evalWith shellOff).config;
    in
    pkgs.writeText "eval-marchyo-shell-off-nixos-keeps-hyprlock" (
      if c.programs.hyprlock.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but NixOS hyprlock is missing on a desktop"
    );

  # With the shell on, the launcher binds summon the in-shell launcher through
  # its global shortcuts.
  eval-marchyo-shell-launcher-binds =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-launcher-binds" (
      if !(hyprHasBind binds "SUPER + R" "hl.dsp.global(\"marchyo:launcher.apps\")") then
        throw "FAIL: SUPER+R should summon the in-shell launcher when the shell is on"
      else if !(hyprHasBind binds "SUPER + CTRL + E" "hl.dsp.global(\"marchyo:launcher.emoji\")") then
        throw "FAIL: SUPER+CTRL+E should summon the in-shell emoji picker when the shell is on"
      else if !(hyprHasBind binds "SUPER + CTRL + T" "hl.dsp.global(\"marchyo:panel.themes\")") then
        throw "FAIL: SUPER+CTRL+T should open the theme picker when the shell is on"
      else if !(hyprHasBind binds "SUPER + CTRL + E" "Emoji picker") then
        throw "FAIL: SUPER+CTRL+E should keep its 'Emoji picker' description (hyprland.nix test depends on it)"
      else if !(hyprHasBind binds "SUPER + CTRL + V" "hl.dsp.global(\"marchyo:launcher.clipboard\")") then
        throw "FAIL: SUPER+Ctrl+V should summon the in-shell clipboard history when the shell is on"
      else
        "pass"
    );

  # The launcher binds need both the shell and marchyo.launcher.enable; without
  # either, Super+R is unbound rather than a dead bind.
  eval-marchyo-shell-launcher-binds-gated =
    let
      bindsFor =
        extra:
        (evalWith extra).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
      hasR = binds: lib.any (e: (e._args or [ ]) != [ ] && builtins.head e._args == "SUPER + R") binds;
    in
    pkgs.writeText "eval-marchyo-shell-launcher-binds-gated" (
      if hasR (bindsFor shellOff) then
        throw "FAIL: marchyo.shell is off but SUPER+R is still bound"
      else if
        hasR (bindsFor {
          marchyo.launcher.enable = false;
        })
      then
        throw "FAIL: marchyo.launcher.enable = false but SUPER+R is still bound"
      else
        "pass"
    );

  # With the shell on, the media keys run the `marchyo volume` / `brightness`
  # verbs (the shell OSD shows the level) and the panel and bar binds dispatch
  # the shell's global shortcuts.
  eval-marchyo-shell-media-and-panel-verbs =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-media-and-panel-verbs" (
      if !(hyprHasBind binds "XF86AudioRaiseVolume" "marchyo volume up") then
        throw "FAIL: XF86AudioRaiseVolume should run 'marchyo volume up' when the shell is on"
      else if !(hyprHasBind binds "XF86AudioMicMute" "marchyo volume mute --mic") then
        throw "FAIL: XF86AudioMicMute should run 'marchyo volume mute --mic' when the shell is on"
      else if !(hyprHasBind binds "XF86MonBrightnessUp" "marchyo brightness up") then
        throw "FAIL: XF86MonBrightnessUp should run 'marchyo brightness up' when the shell is on"
      else if !(hyprHasBind binds "SUPER + CTRL + A" "hl.dsp.global(\"marchyo:panel.audio\")") then
        throw "FAIL: SUPER+CTRL+A should dispatch the panel.audio global shortcut"
      else if
        !(hyprHasBind binds "SUPER + CTRL + O" "hl.dsp.global(\"marchyo:panel.controlcenter\")")
      then
        throw "FAIL: SUPER+SHIFT+Q should dispatch the panel.controlcenter global shortcut"
      else if !(hyprHasBind binds "SUPER + SHIFT + SPACE" "hl.dsp.global(\"marchyo:bar\")") then
        throw "FAIL: SUPER+SHIFT+SPACE should dispatch the bar global shortcut when the shell is on"
      else
        "pass"
    );

  # marchyo.cli.enable = false keeps the shell binds and idle locking working:
  # the binds dispatch global shortcuts, which need no CLI, and idle locking
  # runs the CLI by store path instead of the (absent) `marchyo` on PATH.
  eval-marchyo-shell-verbs-without-cli =
    let
      hm =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.cli.enable = false;
        }).config.home-manager.users.testuser;
      binds = hm.wayland.windowManager.hyprland.settings.bind;
      general = hm.services.hypridle.settings.general;
    in
    pkgs.writeText "eval-marchyo-shell-verbs-without-cli" (
      if !(hyprHasBind binds "SUPER + CTRL + A" "hl.dsp.global(\"marchyo:panel.audio\")") then
        throw "FAIL: with marchyo.cli.enable = false the panel binds should still dispatch global shortcuts"
      else if
        !(hyprHasBind binds "SUPER + CTRL + ALT + comma" "hl.dsp.global(\"marchyo:notifications.silence\")")
      then
        throw "FAIL: with marchyo.cli.enable = false the DND bind should still dispatch its global shortcut"
      else if !(hyprHasBind binds "SUPER + CTRL + L" "/bin/marchyo shell lock") then
        throw "FAIL: with marchyo.cli.enable = false SUPER+CTRL+L should lock through the CLI by store path"
      else if
        !(lib.hasInfix "/bin/marchyo shell lock" (general.lock_cmd or ""))
        || !(lib.hasInfix "/bin/marchyo shell lock" (general.before_sleep_cmd or ""))
      then
        throw "FAIL: with marchyo.cli.enable = false hypridle should lock through the CLI by store path"
      else
        "pass"
    );

  # The notification binds reach the shell through its global shortcuts when it
  # owns notifications (DND, dismiss-all), never through raw IPC.
  eval-marchyo-shell-notification-binds =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-notification-binds" (
      if
        !(hyprHasBind binds "SUPER + CTRL + ALT + comma" "hl.dsp.global(\"marchyo:notifications.silence\")")
      then
        throw "FAIL: SUPER+CTRL+ALT+comma should dispatch notifications.silence when the shell is on"
      else if
        !(hyprHasBind binds "SUPER + SHIFT + comma" "hl.dsp.global(\"marchyo:notifications.dismissAll\")")
      then
        throw "FAIL: SUPER+SHIFT+comma should dispatch notifications.dismissAll when the shell is on"
      else if
        !(hyprHasBind binds "SUPER + CTRL + comma" "hl.dsp.global(\"marchyo:notifications.keyboard\")")
      then
        throw "FAIL: SUPER+CTRL+comma should dispatch notifications.keyboard when the shell is on"
      else if lib.any (e: lib.hasInfix "marchyo-shell ipc" (hyprEntryText e)) binds then
        throw "FAIL: a Hyprland bind still calls marchyo-shell ipc directly"
      else
        "pass"
    );

  # Auto video caffeine: the shell's systemd-inhibit --what=idle only reaches
  # hypridle while hypridle honours logind inhibitors, and the
  # caffeine.autoVideo opt-out must reach the shell.json the shell reads.
  eval-marchyo-shell-caffeine-auto-video =
    let
      hm =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.shell.settings.caffeine.autoVideo = false;
        }).config.home-manager.users.testuser;
      shellJson = builtins.fromJSON hm.xdg.configFile."marchyo/shell.json".text;
    in
    pkgs.writeText "eval-marchyo-shell-caffeine-auto-video" (
      if (hm.services.hypridle.settings.general.ignore_systemd_inhibit or false) then
        throw "FAIL: hypridle ignores systemd idle inhibitors, so the shell's auto video caffeine cannot reach it"
      else if (shellJson.caffeine.autoVideo or true) != false then
        throw "FAIL: marchyo.shell.settings.caffeine.autoVideo = false did not reach shell.json"
      else
        "pass"
    );

  # Polkit cutover: the shell registers the session's polkit agent, and a
  # session holds one, so hyprpolkitagent stands down with the shell on.
  eval-marchyo-shell-disables-hyprpolkitagent =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disables-hyprpolkitagent" (
      if hm.services.hyprpolkitagent.enable || (hm.systemd.user.services ? hyprpolkitagent) then
        throw "FAIL: marchyo.shell.enable = true but hyprpolkitagent is still enabled (two polkit agents)"
      else
        "pass"
    );

  # Desktop with the shell off (the fallback): hyprpolkitagent is the polkit agent.
  eval-marchyo-shell-off-keeps-hyprpolkitagent =
    let
      hm = (evalWith shellOff).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-hyprpolkitagent" (
      if hm.services.hyprpolkitagent.enable && (hm.systemd.user.services ? hyprpolkitagent) then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but hyprpolkitagent is not enabled on a desktop"
    );
}
