# Shell appearance scale axes (marchyo.theme.appearance): the options are
# accepted, default to neutral values, and the shell still evaluates with them
# threaded into the marchyo-shell override.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprEntriesText hyprHasBind;

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
  eval-appearance-defaults-neutral =
    let
      a = (evalWith { }).config.marchyo.theme.appearance;
    in
    pkgs.writeText "eval-appearance-defaults-neutral" (
      if
        a.cornerRadiusScale == 1.0 && a.uiScale == 1.0 && a.animationSpeed == 1.0 && (!a.highContrast)
      then
        "pass"
      else
        throw "FAIL: marchyo.theme.appearance defaults are not neutral"
    );

  # Style axes: the flush strip bar is the default (it fits the gapless grid),
  # and translucent surfaces stay on; the floating pill and the opaque look
  # are opt-ins.
  eval-appearance-style-defaults =
    let
      a = (evalWith { }).config.marchyo.theme.appearance;
    in
    pkgs.writeText "eval-appearance-style-defaults" (
      if !a.floatingBar && a.surfaceAlpha == 0.85 then
        "pass"
      else
        throw "FAIL: marchyo.theme.appearance style defaults should be the strip bar + surfaceAlpha 0.85"
    );

  # Glass: with the shell on and surfaceAlpha below 1, Hyprland must enable the
  # blur effect and register a layer rule for the shell's marchyo: namespaces.
  eval-appearance-shell-glass =
    let
      hm = (evalWith { marchyo.shell.enable = true; }).config.home-manager.users.testuser;
      settings = hm.wayland.windowManager.hyprland.settings;
      rules = hyprEntriesText (settings.layer_rule or [ ]);
      blurEnabled = settings.config.decoration.blur.enabled or false;
    in
    pkgs.writeText "eval-appearance-shell-glass" (
      if blurEnabled && lib.hasInfix "marchyo:" rules && lib.hasInfix "blur=true" rules then
        "pass"
      else
        throw "FAIL: shell on + default surfaceAlpha should enable blur and a marchyo: layer rule"
    );

  # Opaque opt-out: surfaceAlpha = 1.0 keeps the flat look, so no blur effect
  # and no shell blur layer rule may be registered.
  eval-appearance-opaque =
    let
      cfg =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.theme.appearance.surfaceAlpha = 1.0;
        }).config;
      hm = cfg.home-manager.users.testuser;
      settings = hm.wayland.windowManager.hyprland.settings;
      rules = hyprEntriesText (settings.layer_rule or [ ]);
      blurEnabled = settings.config.decoration.blur.enabled or false;
    in
    pkgs.writeText "eval-appearance-opaque" (
      if !blurEnabled && !lib.hasInfix "blur=true" rules then
        "pass"
      else
        throw "FAIL: surfaceAlpha = 1.0 should keep blur off and register no blur layer rule"
    );

  # Reduced motion defaults on in a VM guest and off on bare metal; when on it
  # drops compositor animations and blur.
  eval-appearance-reduce-motion =
    let
      host = (evalWith { marchyo.shell.enable = true; }).config;
      guest =
        (evalWith {
          marchyo.shell.enable = true;
          services.qemuGuest.enable = true;
        }).config;
      settings = guest.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
    in
    pkgs.writeText "eval-appearance-reduce-motion" (
      if
        !host.marchyo.theme.appearance.reduceMotion
        && guest.marchyo.theme.appearance.reduceMotion
        && !settings.config.animations.enabled
        && !(settings.config.decoration.blur.enabled or false)
      then
        "pass"
      else
        throw "FAIL: reduceMotion should default on in a VM guest and disable animations and blur"
    );

  # Non-neutral axes are accepted and the shell evaluates with them.
  eval-appearance-threaded =
    let
      cfg =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.theme.appearance = {
            cornerRadiusScale = 0.0;
            uiScale = 1.5;
            animationSpeed = 2.0;
            highContrast = true;
          };
        }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-appearance-threaded" (
      if (hm.systemd.user.services ? marchyo-shell) && cfg.marchyo.theme.appearance.highContrast then
        "pass"
      else
        throw "FAIL: appearance axes set but the shell did not evaluate with them"
    );

  # Window appearance defaults reproduce the flat look: opaque windows, square
  # corners, auto animations (on with the shell, decided against a VM at start).
  eval-appearance-window-defaults =
    let
      cfg = (evalWith { marchyo.shell.enable = true; }).config;
      a = cfg.marchyo.theme.appearance;
      hm = cfg.home-manager.users.testuser;
      settings = hm.wayland.windowManager.hyprland.settings;
      decoration = settings.config.decoration;
      startup = hyprEntriesText settings.on;
    in
    pkgs.writeText "eval-appearance-window-defaults" (
      if
        a.transparency == "opaque"
        && a.corners == "theme"
        && a.animations == "auto"
        && decoration.rounding == 0
        && !(decoration ? active_opacity)
        && settings.config.animations.enabled
        && lib.hasInfix "marchyo-vm-animations-off" startup
        && hm.xdg.configFile ? "marchyo/appearance.json"
      then
        "pass"
      else
        throw "FAIL: window appearance defaults are not the flat opaque look with auto animations"
    );

  # Forced animation states: no VM check is wired, and the compositor state follows.
  eval-appearance-animations-forced =
    let
      settingsFor =
        mode:
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.theme.appearance.animations = mode;
        }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
      off = settingsFor "off";
      on = settingsFor "on";
      noShell =
        (evalWith { marchyo.theme.appearance.animations = "on"; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
    in
    pkgs.writeText "eval-appearance-animations-forced" (
      if
        !off.config.animations.enabled
        && on.config.animations.enabled
        && noShell.config.animations.enabled
        && !lib.hasInfix "marchyo-vm-animations-off" (hyprEntriesText off.on)
        && !lib.hasInfix "marchyo-vm-animations-off" (hyprEntriesText on.on)
      then
        "pass"
      else
        throw "FAIL: animations = on/off should force the state and skip the VM check"
    );

  # Transparent: translucent windows without blur (shell off, so no shell glass).
  eval-appearance-transparent =
    let
      settings =
        (evalWith {
          marchyo.shell.enable = false;
          marchyo.theme.appearance.transparency = "transparent";
        }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
      decoration = settings.config.decoration;
    in
    pkgs.writeText "eval-appearance-transparent" (
      if
        decoration.active_opacity == 0.92
        && decoration.inactive_opacity == 0.85
        && !(decoration.blur.enabled or false)
      then
        "pass"
      else
        throw "FAIL: transparent windows should be translucent without blur"
    );

  # Glassy: blur on, translucent windows, and windows are no longer opted out of blur.
  eval-appearance-glassy =
    let
      settings =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.theme.appearance.transparency = "glassy";
        }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
      decoration = settings.config.decoration;
      windowRules = hyprEntriesText settings.window_rule;
      layerRules = hyprEntriesText settings.layer_rule;
    in
    pkgs.writeText "eval-appearance-glassy" (
      if
        decoration.blur.enabled
        && decoration.active_opacity == 0.92
        && !lib.hasInfix "no_blur=true" windowRules
        && lib.hasInfix "blur=true" layerRules
      then
        "pass"
      else
        throw "FAIL: glassy should blur windows and the shell without a no_blur window rule"
    );

  # Reduced motion wins over glassy: opaque windows, no blur.
  eval-appearance-glassy-reduce-motion =
    let
      settings =
        (evalWith {
          marchyo.shell.enable = true;
          marchyo.theme.appearance = {
            transparency = "glassy";
            reduceMotion = true;
          };
        }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
    in
    pkgs.writeText "eval-appearance-glassy-reduce-motion" (
      if
        !(settings.config.decoration.blur.enabled or false)
        && !(settings.config.decoration ? active_opacity)
      then
        "pass"
      else
        throw "FAIL: reduceMotion should keep windows opaque and unblurred even with glassy"
    );

  # Rounded corners round the windows; sharp stays square.
  eval-appearance-corners =
    let
      decorationFor =
        mode:
        (evalWith { marchyo.theme.appearance.corners = mode; })
        .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.config.decoration;
      rounded = decorationFor "rounded";
      sharp = decorationFor "sharp";
    in
    pkgs.writeText "eval-appearance-corners" (
      if rounded.rounding == 6 && rounded.rounding_power == 3 && sharp.rounding == 0 then
        "pass"
      else
        throw "FAIL: corners = rounded should round windows and sharp keep them square"
    );

  # Window utilities: the pop-out bind and the recentre-on-monitor-move hook.
  eval-appearance-window-utilities =
    let
      settings =
        (evalWith { }).config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
    in
    pkgs.writeText "eval-appearance-window-utilities" (
      if
        hyprHasBind settings.bind "SUPER + ALT + O" "marchyo window pop"
        && lib.hasInfix "window.move_to_workspace" (hyprEntriesText settings.on)
      then
        "pass"
      else
        throw "FAIL: the pop-out bind or the monitor-move recentre hook is missing"
    );
}
