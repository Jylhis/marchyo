{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntriesText;

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

  binds = hm: hm.wayland.windowManager.hyprland.settings.bind or [ ];
  hasBind = hm: hyprHasBind (binds hm);
  bindsText = hm: hyprEntriesText (binds hm);
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
        && hasBind hm "XF86AudioRaiseVolume" ''hl.dsp.exec_cmd("swayosd-client --output-volume raise")''
        && hasBind hm "XF86MonBrightnessDown" ''hl.dsp.exec_cmd("swayosd-client --brightness lower")''
        && !(hasBind hm "XF86AudioRaiseVolume" "wpctl")
        && !(hasBind hm "XF86MonBrightnessDown" "brightnessctl")
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
        && hasBind hm "XF86AudioRaiseVolume" "wpctl set-volume"
        && hasBind hm "XF86MonBrightnessDown" "brightnessctl"
        && !(lib.hasInfix "swayosd-client" (bindsText hm))
        && !(hasUdevSwayosd cfg)
        && !(lib.elem "video" cfg.users.users.testuser.extraGroups)
      then
        "pass"
      else
        throw "FAIL: marchyo.osd.enable = false but swayosd service/binds, udev rules, or the video group are still present"
    );
}
