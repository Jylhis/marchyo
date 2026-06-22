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
  inherit (helpers) withTestUser;

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
}
