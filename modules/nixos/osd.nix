# System-level SwayOSD wiring. The OSD itself lives in modules/home/swayosd.nix
# (home-manager server unit + hyprland.nix media binds), but brightness control
# writes /sys/class/backlight/*/brightness directly, which needs the udev rules
# shipped with the swayosd package plus membership in the `video` group.
# Without this half, volume OSD works but the brightness keys silently no-op.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  mUsers = lib.filterAttrs (_name: user: user.enable) cfg.users;
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.osd.enable) {
    # 99-swayosd.rules: chgrp video + g+w on backlight/led brightness nodes.
    services.udev.packages = [ pkgs.swayosd ];

    # extraGroups list-merges with the base groups set in modules/nixos/system.nix.
    users.users = lib.mapAttrs (_name: _user: {
      extraGroups = [ "video" ];
    }) mUsers;
  };
}
