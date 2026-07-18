{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

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

  bindel = hm: hm.wayland.windowManager.hyprland.settings.bindel or [ ];
  hasBindel = hm: s: lib.any (b: lib.hasInfix s b) (bindel hm);
in
{
  # OSD on by default with the desktop: the swayosd-server user service is
  # defined and the media keys route through swayosd-client.
  eval-osd-default =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-osd-default" (
      if
        (hm.systemd.user.services ? swayosd)
        && hasBindel hm "XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        && hasBindel hm "XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
        && !(hasBindel hm "wpctl")
      then
        "pass"
      else
        throw "FAIL: desktop with default osd is missing the swayosd service or swayosd-client media binds"
    );

  # OSD disabled: no swayosd service, media keys fall back to the silent
  # wpctl/brightnessctl commands.
  eval-osd-disabled =
    let
      hm = (evalWith { marchyo.osd.enable = false; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-osd-disabled" (
      if
        !(hm.systemd.user.services ? swayosd)
        && hasBindel hm "XF86AudioRaiseVolume, exec, wpctl set-volume"
        && hasBindel hm "XF86MonBrightnessDown, exec, brightnessctl"
        && !(hasBindel hm "swayosd-client")
      then
        "pass"
      else
        throw "FAIL: marchyo.osd.enable = false but the swayosd service or swayosd-client binds are still present"
    );
}
