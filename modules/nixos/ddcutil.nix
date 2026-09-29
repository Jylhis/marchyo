# Desktop-only DDC/CI external-monitor brightness. Gated on the desktop and the
# marchyo.hardware.ddc.enable opt-out sub-toggle (localsend pattern).
#
# hardware.i2c.enable loads i2c-dev, ships the udev rules, and creates the `i2c`
# group; users still have to be members to talk to the bus, so add the Marchyo
# users here (extraGroups list-merges with the base set in system.nix, same
# idiom as modules/nixos/osd.nix).
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
