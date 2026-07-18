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
  hasUdevSwayosd = cfg: lib.any (p: lib.getName p == "swayosd") cfg.services.udev.packages;
in
{
  # OSD on by default with the desktop: the swayosd-server user service is
  # defined, the media keys route through swayosd-client, and the system half
  # (backlight udev rules + video group for marchyo users) is wired.
  eval-osd-default =
    let
      cfg = (evalWith { }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-osd-default" (
      if
        (hm.systemd.user.services ? swayosd)
        && hasBindel hm "XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        && hasBindel hm "XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
        && !(hasBindel hm "XF86AudioRaiseVolume, exec, wpctl")
        && !(hasBindel hm "XF86MonBrightnessDown, exec, brightnessctl")
        && hasUdevSwayosd cfg
        && lib.elem "video" cfg.users.users.testuser.extraGroups
      then
        "pass"
      else
        throw "FAIL: desktop with default osd is missing the swayosd service, swayosd-client media binds, backlight udev rules, or the video group"
    );

  # OSD disabled: no swayosd service or udev rules, media keys fall back to
  # the silent wpctl/brightnessctl commands.
  eval-osd-disabled =
    let
      cfg = (evalWith { marchyo.osd.enable = false; }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-osd-disabled" (
      if
        !(hm.systemd.user.services ? swayosd)
        && hasBindel hm "XF86AudioRaiseVolume, exec, wpctl set-volume"
        && hasBindel hm "XF86MonBrightnessDown, exec, brightnessctl"
        && !(hasBindel hm "swayosd-client")
        && !(hasUdevSwayosd cfg)
        && !(lib.elem "video" cfg.users.users.testuser.extraGroups)
      then
        "pass"
      else
        throw "FAIL: marchyo.osd.enable = false but swayosd service/binds, udev rules, or the video group are still present"
    );
}
