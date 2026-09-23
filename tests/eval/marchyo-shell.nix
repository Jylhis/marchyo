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

  # SUPER+L reaches the running shell over IPC when it is on; hyprlock when off.
  eval-marchyo-shell-lock-bind =
    let
      bind =
        (evalWith { marchyo.shell.enable = true; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind;
    in
    pkgs.writeText "eval-marchyo-shell-lock-bind" (
      if hyprHasBind bind "SUPER + L" "shell lock" then
        "pass"
      else
        throw "FAIL: SUPER+L should call 'shell lock' over IPC when the shell is enabled"
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

  # hypridle stays the idle authority, but its lock points (general.lock_cmd,
  # before_sleep_cmd, the 300s listener) target the shell's IPC when it is on.
  eval-marchyo-shell-hypridle-locks-via-ipc =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
      general = hm.services.hypridle.settings.general;
      # toJSON, not toString: the listeners are attrsets, which toString
      # cannot coerce.
      listenersText = builtins.toJSON hm.services.hypridle.settings.listener;
      ok =
        lib.hasInfix "shell lock" (general.lock_cmd or "")
        && lib.hasInfix "shell lock" (general.before_sleep_cmd or "")
        && lib.hasInfix "shell lock" listenersText;
    in
    pkgs.writeText "eval-marchyo-shell-hypridle-locks-via-ipc" (
      if ok then
        "pass"
      else
        throw "FAIL: hypridle lock commands do not target the shell IPC when marchyo.shell is on"
    );

  eval-marchyo-shell-off-hypridle-keeps-loginctl =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
      listenersText = builtins.toJSON hm.services.hypridle.settings.listener;
    in
    pkgs.writeText "eval-marchyo-shell-off-hypridle-keeps-loginctl" (
      if
        lib.hasInfix "loginctl lock-session" listenersText
        && !lib.hasInfix "marchyo-shell ipc" listenersText
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
}
