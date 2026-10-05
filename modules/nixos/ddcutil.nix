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
  config = lib.mkIf (cfg.desktop.enable && cfg.hardware.ddc.enable) {
    hardware.i2c.enable = true;
    environment.systemPackages = [ pkgs.ddcutil ];
    users.users = lib.mapAttrs (_name: _user: {
      extraGroups = [ "i2c" ];
    }) mUsers;
  };
}
