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
  inherit (helpers) withTestUser hyprEntriesText;

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

  # Style axes are deliberately non-neutral: the Caelestia-inspired look
  # (floating pill bar, translucent surfaces) is the default, and the strip /
  # opaque look is the opt-out.
  eval-appearance-style-defaults =
    let
      a = (evalWith { }).config.marchyo.theme.appearance;
    in
    pkgs.writeText "eval-appearance-style-defaults" (
      if a.floatingBar && a.surfaceAlpha == 0.85 then
        "pass"
      else
        throw "FAIL: marchyo.theme.appearance style defaults should be floatingBar + surfaceAlpha 0.85"
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
  # and no shell layer rule may be registered.
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
      if !blurEnabled && !lib.hasInfix "marchyo:" rules then
        "pass"
      else
        throw "FAIL: surfaceAlpha = 1.0 should keep blur off and register no marchyo: layer rule"
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
}
