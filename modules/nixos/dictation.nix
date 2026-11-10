# System-level dictation wiring. The per-user services live in
# modules/home/dictation.nix and modules/home/voxtype.nix (home-manager).
#
# The voxtype daemon's evdev push-to-talk hotkey reads /dev/input, so users
# join the `input` group (only when that hotkey is on).
{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo.dictation;
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;

  isVoxtype = cfg.backend == "voxtype";
in
{
  # extraGroups list-merges with the base groups set in modules/nixos/system.nix.
  config = lib.mkIf (cfg.enable && isVoxtype && cfg.pushToTalk.enable) {
    users.users = lib.mapAttrs (_name: _user: {
      extraGroups = [ "input" ];
    }) mUsers;
  };
}
