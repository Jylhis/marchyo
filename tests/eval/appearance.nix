# Shell appearance (marchyo.theme.appearance): the options are accepted,
# default to neutral values, and reach Hyprland and the shell. The non-default
# settings each reference system carries are in refConfig at the bottom.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprEntriesText hyprHasBind;
  settingsOf = c: c.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
in
{
  refs = {
    desktop = {
      eval-appearance-defaults-neutral =
        c:
        let
          a = c.marchyo.theme.appearance;
        in
        if
          a.cornerRadiusScale == 1.0 && a.uiScale == 1.0 && a.animationSpeed == 1.0 && (!a.highContrast)
        then
          true
        else
          "marchyo.theme.appearance defaults are not neutral";

      # Style axes: the flush strip bar is the default (it fits the gapless grid),
      # and translucent surfaces stay on; the floating pill and the opaque look
      # are opt-ins.
      eval-appearance-style-defaults =
        c:
        let
          a = c.marchyo.theme.appearance;
        in
        if !a.floatingBar && a.surfaceAlpha == 0.85 then
          true
        else
          "marchyo.theme.appearance style defaults should be the strip bar + surfaceAlpha 0.85";

      # Glass: with the shell on and surfaceAlpha below 1, Hyprland must enable the
      # blur effect and register a layer rule for the shell's marchyo: namespaces.
      eval-appearance-shell-glass =
        c:
        let
          hm = c.home-manager.users.testuser;
          settings = hm.wayland.windowManager.hyprland.settings;
          rules = hyprEntriesText (settings.layer_rule or [ ]);
          blurEnabled = settings.config.decoration.blur.enabled or false;
        in
        if blurEnabled && lib.hasInfix "marchyo:" rules && lib.hasInfix "blur=true" rules then
          true
        else
          "shell on + default surfaceAlpha should enable blur and a marchyo: layer rule";

      # Window appearance defaults reproduce the flat look: opaque windows, square
      # corners, auto animations (on with the shell, decided against a VM at start).
      eval-appearance-window-defaults =
        cfg:
        let
          a = cfg.marchyo.theme.appearance;
          hm = cfg.home-manager.users.testuser;
          settings = hm.wayland.windowManager.hyprland.settings;
          decoration = settings.config.decoration;
          startup = hyprEntriesText settings.on;
        in
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
          true
        else
          "window appearance defaults are not the flat opaque look with auto animations";

      # Window utilities: the pop-out bind and the recentre-on-monitor-move hook.
      eval-appearance-window-utilities =
        c:
        let
          settings = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
        in
        if
          hyprHasBind settings.bind "SUPER + ALT + O" "marchyo window pop"
          && lib.hasInfix "window.move_to_workspace" (hyprEntriesText settings.on)
        then
          true
        else
          "the pop-out bind or the monitor-move recentre hook is missing";
    };

    desktop-tweaks = {
      # Opaque opt-out: surfaceAlpha = 1.0 keeps the flat look, so no blur effect
      # and no shell blur layer rule may be registered.
      eval-appearance-opaque =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          settings = hm.wayland.windowManager.hyprland.settings;
          rules = hyprEntriesText (settings.layer_rule or [ ]);
          blurEnabled = settings.config.decoration.blur.enabled or false;
        in
        if !blurEnabled && !lib.hasInfix "blur=true" rules then
          true
        else
          "surfaceAlpha = 1.0 should keep blur off and register no blur layer rule";
    };

    desktop-tweaks-3 = {
      # Reduced motion defaults on in a VM guest and off on bare metal; when on it
      # drops compositor animations and blur.
      eval-appearance-reduce-motion =
        c:
        let
          guest = c;
          settings = guest.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
        in
        if
          guest.marchyo.theme.appearance.reduceMotion
          && !settings.config.animations.enabled
          && !(settings.config.decoration.blur.enabled or false)
        then
          true
        else
          "reduceMotion should default on in a VM guest and disable animations and blur";
    };

    desktop-tweaks-4 = {
      # Non-neutral axes are accepted and the shell evaluates with them.
      eval-appearance-threaded =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        if (hm.systemd.user.services ? marchyo-shell) && cfg.marchyo.theme.appearance.highContrast then
          true
        else
          "appearance axes set but the shell did not evaluate with them";

      # Reduced motion wins over glassy: opaque windows, no blur.
      eval-appearance-glassy-reduce-motion =
        c:
        let
          settings = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
        in
        if
          !(settings.config.decoration.blur.enabled or false)
          && !(settings.config.decoration ? active_opacity)
        then
          true
        else
          "reduceMotion should keep windows opaque and unblurred even with glassy";
    };

    desktop-tweaks-2 = {
      # Forced animation states: no VM check is wired, and the compositor state follows.
      eval-appearance-animations-forced =
        c:
        let
          on = settingsOf c;
        in
        if
          on.config.animations.enabled && !lib.hasInfix "marchyo-vm-animations-off" (hyprEntriesText on.on)
        then
          true
        else
          "animations = on should force the state and skip the VM check";

      # Glassy: blur on, translucent windows, and windows are no longer opted out of blur.
      eval-appearance-glassy =
        c:
        let
          settings = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
          decoration = settings.config.decoration;
          windowRules = hyprEntriesText settings.window_rule;
          layerRules = hyprEntriesText settings.layer_rule;
        in
        if
          decoration.blur.enabled
          && decoration.active_opacity == 0.92
          && !lib.hasInfix "no_blur=true" windowRules
          && lib.hasInfix "blur=true" layerRules
        then
          true
        else
          "glassy should blur windows and the shell without a no_blur window rule";

      # Rounded corners round the windows; sharp stays square.
      eval-appearance-corners =
        c:
        let
          rounded = (settingsOf c).config.decoration;
        in
        if rounded.rounding == 6 && rounded.rounding_power == 3 then
          true
        else
          "corners = rounded should round windows";
    };

    shell-off-tweaks = {
      # Transparent: translucent windows without blur (shell off, so no shell glass).
      eval-appearance-transparent =
        c:
        let
          settings = c.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
          decoration = settings.config.decoration;
        in
        if
          decoration.active_opacity == 0.92
          && decoration.inactive_opacity == 0.85
          && !(decoration.blur.enabled or false)
        then
          true
        else
          "transparent windows should be translucent without blur";
    };

    # The parts of the tests above that read the other side of a setting.
    # Reduced motion stays off on bare metal.
    desktop.eval-appearance-reduce-motion-host = c: !c.marchyo.theme.appearance.reduceMotion;

    # animations = "off" (desktop-tweaks-4) forces animations off and skips the
    # VM check.
    desktop-tweaks-4.eval-appearance-animations-forced-off =
      c:
      let
        off = settingsOf c;
      in
      helpers.expect (
        !off.config.animations.enabled && !lib.hasInfix "marchyo-vm-animations-off" (hyprEntriesText off.on)
      ) "animations = off should force the state and skip the VM check";

    # animations = "on" forces animations even without the shell (shell-off-tweaks).
    shell-off-tweaks.eval-appearance-animations-forced-no-shell =
      c:
      helpers.expect (settingsOf c).config.animations.enabled "animations = on without the shell should still enable animations";

    # corners = "sharp" (desktop-tweaks) keeps windows square.
    desktop-tweaks.eval-appearance-corners-sharp =
      c:
      helpers.expect (
        (settingsOf c).config.decoration.rounding == 0
      ) "corners = sharp should keep windows square";
  };

  refConfig = {
    desktop-tweaks.marchyo.theme.appearance = {
      surfaceAlpha = 1.0;
      corners = "sharp";
    };
    desktop-tweaks-2.marchyo.theme.appearance = {
      transparency = "glassy";
      corners = "rounded";
      animations = "on";
    };
    # A VM guest: reduceMotion defaults on.
    desktop-tweaks-3.services.qemuGuest.enable = true;
    desktop-tweaks-4.marchyo.theme.appearance = {
      cornerRadiusScale = 0.0;
      uiScale = 1.5;
      animationSpeed = 2.0;
      highContrast = true;
      animations = "off";
      transparency = "glassy";
      reduceMotion = true;
    };
    shell-off-tweaks.marchyo.theme.appearance = {
      animations = "on";
      transparency = "transparent";
    };
  };
}
