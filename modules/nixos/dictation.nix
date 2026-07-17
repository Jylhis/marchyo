# System-level dictation wiring. The dictation feature itself lives in
# modules/home/voxtype.nix (home-manager), but the daemon's evdev push-to-talk
# hotkey has to read /dev/input, which requires the user to be in the `input`
# group. Scoped to when both dictation and its push-to-talk hotkey are on, so a
# host using only the Hyprland toggle bind gains no extra group membership.
{ config, lib, ... }:
let
  cfg = config.marchyo.dictation;
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
in
{
  config = lib.mkIf (cfg.enable && cfg.pushToTalk.enable) {
    # extraGroups list-merges with the base groups set in modules/nixos/system.nix.
    users.users = lib.mapAttrs (_name: _user: {
      extraGroups = [ "input" ];
    }) mUsers;
  };
}
