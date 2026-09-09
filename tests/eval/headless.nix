# Headless / server path: marchyo's NixOS module (with a marchyo user, so the
# full modules/home set is imported) must produce NO Wayland desktop-shell
# config when marchyo.desktop.enable is off. This is what lets a headless host
# build through lib.mkNixosSystem + marchyo.users.* instead of opting out of
# marchyo's HM entirely. The same guards make the modules inert on darwin.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hmOf =
    cfg:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser cfg)
      ];
    }).config.home-manager.users.testuser;
in
{
  # desktop disabled => the Wayland shell modules are all inert.
  eval-headless-no-wayland =
    let
      hm = hmOf { marchyo.desktop.enable = false; };
      offenders =
        lib.optional hm.wayland.windowManager.hyprland.enable "hyprland"
        ++ lib.optional hm.programs.waybar.enable "waybar"
        ++ lib.optional hm.programs.hyprlock.enable "hyprlock"
        ++ lib.optional hm.services.hypridle.enable "hypridle"
        ++ lib.optional hm.programs.vicinae.enable "vicinae"
        ++ lib.optional hm.programs.noctalia.enable "noctalia";
    in
    pkgs.writeText "eval-headless-no-wayland" (
      if offenders == [ ] then
        "pass"
      else
        throw "FAIL: desktop disabled but these are still enabled in HM: ${lib.concatStringsSep ", " offenders}"
    );

  # desktop enabled => the same modules ARE configured (the guard does not
  # over-gate the normal desktop path).
  eval-desktop-enables-wayland =
    let
      hm = hmOf { marchyo.desktop.enable = true; };
    in
    pkgs.writeText "eval-desktop-enables-wayland" (
      if hm.wayland.windowManager.hyprland.enable && hm.programs.waybar.enable then
        "pass"
      else
        throw "FAIL: desktop enabled but hyprland/waybar were not configured"
    );

  # The NixOS half of the same contract. The tests above only inspect Home
  # Manager, which is why modules/nixos/{hyprland,printing,hyprlock,_1password}
  # and hardware.nix's bluetooth stanza went on enabling themselves on headless
  # hosts unnoticed.
  eval-headless-no-desktop-services =
    testNixOSCheck "headless-no-desktop-services"
      (
        cfg:
        let
          offenders =
            lib.optional cfg.programs.hyprland.enable "programs.hyprland"
            ++ lib.optional cfg.programs.hyprlock.enable "programs.hyprlock"
            ++ lib.optional cfg.xdg.portal.enable "xdg.portal"
            ++ lib.optional cfg.services.printing.enable "services.printing"
            ++ lib.optional cfg.services.colord.enable "services.colord"
            ++ lib.optional cfg.hardware.bluetooth.enable "hardware.bluetooth"
            ++ lib.optional cfg.programs._1password-gui.enable "programs._1password-gui";
        in
        if offenders == [ ] then
          true
        else
          throw "FAIL: desktop disabled but these are still enabled: ${lib.concatStringsSep ", " offenders}"
      )
      (withTestUser {
        marchyo.desktop.enable = false;
      });

  eval-desktop-enables-services =
    testNixOSCheck "desktop-enables-services"
      (
        cfg:
        cfg.programs.hyprland.enable
        && cfg.xdg.portal.enable
        && cfg.services.printing.enable
        && cfg.hardware.bluetooth.enable
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Overridability: with the desktop on, a consumer must be able to turn an
  # individual service off without lib.mkForce. Before the mkDefault sweep this
  # was a "conflicting definition values" eval error.
  eval-desktop-services-overridable =
    testNixOSCheck "desktop-services-overridable"
      (cfg: !cfg.services.printing.enable && !cfg.hardware.bluetooth.enable)
      (withTestUser {
        marchyo.desktop.enable = true;
        services.printing.enable = false;
        hardware.bluetooth.enable = false;
      });
}
