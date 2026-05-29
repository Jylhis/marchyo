# Derive nix-darwin's `system.primaryUser` from marchyo's user model.
# Several darwin options (homebrew, system.defaults user preferences) require a
# primary user; default it to the first enabled marchyo user so the curated
# darwin defaults work out of the box. Overridable downstream.
{ lib, config, ... }:
let
  enabledUsers = lib.attrNames (lib.filterAttrs (_: u: u.enable) config.marchyo.users);
in
{
  config = lib.mkIf (enabledUsers != [ ]) {
    system.primaryUser = lib.mkDefault (builtins.head enabledUsers);
  };
}
