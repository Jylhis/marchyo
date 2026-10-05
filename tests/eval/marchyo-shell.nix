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

  # Notification cutover: the shell owns org.freedesktop.Notifications and draws
  # its own toasts, so with the shell on mako must stand down — the two daemons
  # never both bind the notification bus.
  eval-marchyo-shell-disables-mako =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disables-mako" (
      if !hm.services.mako.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell.enable = true but mako is still enabled (both would seize org.freedesktop.Notifications)"
    );

  # Plain desktop (shell off): mako is the notification daemon, so it must be on.
  eval-marchyo-shell-off-keeps-mako =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-mako" (
      if hm.services.mako.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but mako is not enabled under a plain desktop"
    );

  # Phase 4 lock cutover: with the shell on, hyprlock stands down (the shell's
  # WlSessionLock owns the lock) — same mutual exclusion as waybar/mako/swayosd.
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
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-hyprlock" (
      if hm.programs.hyprlock.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but hyprlock is missing under a plain desktop"
    );

  # SUPER+L reaches the running shell through `marchyo shell lock` when it is
  # on; hyprlock when off.
  eval-marchyo-shell-lock-bind =
    let
      bind =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-lock-bind" (
      if hyprHasBind bind "SUPER + L" "marchyo shell lock" then
        "pass"
      else
        throw "FAIL: SUPER+L should run 'marchyo shell lock' when the shell is enabled"
    );

  eval-marchyo-shell-off-keeps-hyprlock-bind =
    let
      bind =
        (evalWith { }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-hyprlock-bind" (
      if hyprHasBind bind "SUPER + L" "hyprlock" then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but SUPER+L no longer execs hyprlock"
    );

  # SUPER+grave summons the window overview through `marchyo shell overview`
  # when the shell is on, and is the only bind on that chord; with the shell
  # off there is no overview and no bind.
  eval-marchyo-shell-overview-bind =
    let
      bindsFor =
        extra:
        (evalWith extra).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
      on = bindsFor { marchyo.shell.enable = true; };
      off = bindsFor { };
      onChord = lib.filter (e: (e._args or [ ]) != [ ] && builtins.head e._args == "SUPER + grave") on;
    in
    pkgs.writeText "eval-marchyo-shell-overview-bind" (
      if !(hyprHasBind on "SUPER + grave" "marchyo shell overview") then
        throw "FAIL: SUPER+grave should run 'marchyo shell overview' when the shell is on"
      else if lib.length onChord != 1 then
        throw "FAIL: SUPER+grave should carry exactly one bind, found ${toString (lib.length onChord)}"
      else if lib.any (e: lib.hasInfix "marchyo shell overview" (hyprEntryText e)) off then
        throw "FAIL: marchyo.shell is off but a bind still runs 'marchyo shell overview'"
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
      hm = (evalWith { }).config.home-manager.users.testuser;
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
      c = (evalWith { }).config;
    in
    pkgs.writeText "eval-marchyo-shell-off-nixos-keeps-hyprlock" (
      if c.programs.hyprlock.enable then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but NixOS hyprlock is missing under a plain desktop"
    );

  # Launcher cutover: the shell ships its own launcher surface, so with the
  # shell on vicinae must stand down — daemon and input-server wrapper both —
  # the two launchers never both answer Super+R.
  eval-marchyo-shell-disables-vicinae =
    let
      cfg = (evalWith { marchyo.shell.enable = true; }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-disables-vicinae" (
      if hm.programs.vicinae.enable then
        throw "FAIL: marchyo.shell.enable = true but vicinae is still enabled (both launchers would run)"
      else if cfg.programs.vicinae.input-server.enable then
        throw "FAIL: marchyo.shell.enable = true but the cap_dac_override input-server wrapper is still installed"
      else
        "pass"
    );

  # With the shell on, the three launcher binds summon the in-shell launcher
  # through `marchyo shell launcher` instead of spawning vicinae.
  eval-marchyo-shell-launcher-binds =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-launcher-binds" (
      if !(hyprHasBind binds "SUPER + R" "marchyo shell launcher apps") then
        throw "FAIL: SUPER+R should summon the in-shell launcher when the shell is on"
      else if !(hyprHasBind binds "SUPER + period" "marchyo shell launcher emoji") then
        throw "FAIL: SUPER+period should summon the in-shell emoji picker when the shell is on"
      else if !(hyprHasBind binds "SUPER + period" "Emoji picker") then
        throw "FAIL: SUPER+period should keep its 'Emoji picker' description (hyprland.nix test depends on it)"
      else if !(hyprHasBind binds "SUPER + CTRL + V" "marchyo shell launcher clipboard") then
        throw "FAIL: SUPER+Ctrl+V should summon the in-shell clipboard history when the shell is on"
      else
        "pass"
    );

  # Plain desktop (shell off): vicinae remains the launcher, and its binds
  # still spawn vicinae.
  eval-marchyo-shell-off-keeps-vicinae =
    let
      c = (evalWith { }).config;
      hm = c.home-manager.users.testuser;
      binds = hm.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-vicinae" (
      if !hm.programs.vicinae.enable then
        throw "FAIL: marchyo.shell is off but vicinae is not enabled under a plain desktop"
      else if !(hyprHasBind binds "SUPER + R" "vicinae toggle") then
        throw "FAIL: marchyo.shell is off but SUPER+R does not spawn vicinae"
      else
        "pass"
    );

  # With the shell on, the media keys run the `marchyo volume` / `brightness`
  # verbs (the shell OSD shows the level) and the panel and bar binds run
  # `marchyo shell`.
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
      else if !(hyprHasBind binds "SUPER + SHIFT + V" "marchyo shell toggle audio") then
        throw "FAIL: SUPER+SHIFT+V should run 'marchyo shell toggle audio'"
      else if !(hyprHasBind binds "SUPER + SHIFT + Q" "marchyo shell toggle controlcenter") then
        throw "FAIL: SUPER+SHIFT+Q should run 'marchyo shell toggle controlcenter'"
      else if !(hyprHasBind binds "SUPER + SHIFT + SPACE" "marchyo shell bar") then
        throw "FAIL: SUPER+SHIFT+SPACE should run 'marchyo shell bar' when the shell is on"
      else
        "pass"
    );

  # marchyo.cli.enable = false keeps the shell binds and idle locking working:
  # they run the CLI by store path instead of the (absent) `marchyo` on PATH.
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
      if !(hyprHasBind binds "SUPER + SHIFT + V" "/bin/marchyo shell toggle audio") then
        throw "FAIL: with marchyo.cli.enable = false the shell binds should run the CLI by store path"
      else if !(hyprHasBind binds "SUPER + CTRL + comma" "/bin/marchyo shell dnd") then
        throw "FAIL: with marchyo.cli.enable = false the DND bind should run the CLI by store path"
      else if
        !(lib.hasInfix "/bin/marchyo shell lock" (general.lock_cmd or ""))
        || !(lib.hasInfix "/bin/marchyo shell lock" (general.before_sleep_cmd or ""))
      then
        throw "FAIL: with marchyo.cli.enable = false hypridle should lock through the CLI by store path"
      else
        "pass"
    );

  # The notification binds reach the shell through `marchyo shell` verbs when it
  # owns notifications (DND, dismiss-all), never through raw IPC.
  eval-marchyo-shell-notification-binds =
    let
      binds =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-notification-binds" (
      if !(hyprHasBind binds "SUPER + CTRL + comma" "marchyo shell dnd") then
        throw "FAIL: SUPER+CTRL+comma should run 'marchyo shell dnd' when the shell is on"
      else if !(hyprHasBind binds "SUPER + CTRL + SHIFT + comma" "marchyo shell dismiss --all") then
        throw "FAIL: SUPER+CTRL+SHIFT+comma should run 'marchyo shell dismiss --all' when the shell is on"
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

  # Plain desktop (shell off): hyprpolkitagent is the polkit agent.
  eval-marchyo-shell-off-keeps-hyprpolkitagent =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-marchyo-shell-off-keeps-hyprpolkitagent" (
      if hm.services.hyprpolkitagent.enable && (hm.systemd.user.services ? hyprpolkitagent) then
        "pass"
      else
        throw "FAIL: marchyo.shell is off but hyprpolkitagent is not enabled under a plain desktop"
    );
}
