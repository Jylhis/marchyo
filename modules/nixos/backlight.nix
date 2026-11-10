# Backlight access for the brightness keys. brightnessctl writes
# /sys/class/backlight/*/brightness directly; the udev rules shipped with the
# brightnessctl package make that node writable by the `video` group.
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
  config = lib.mkIf cfg.desktop.enable {
    services.udev.packages = [ pkgs.brightnessctl ];

    # extraGroups list-merges with the base groups set in modules/nixos/system.nix.
    users.users = lib.mapAttrs (_name: _user: {
      extraGroups = [ "video" ];
    }) mUsers;
  };
}
