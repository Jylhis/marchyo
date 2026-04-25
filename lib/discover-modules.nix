# Auto-discovery helper for module import lists.
#
# Returns every `.nix` file directly under `dir` (excluding `default.nix`)
# plus any subdirectory containing a `default.nix`.
#
# Usage in modules/<target>/default.nix:
#   { ... }:
#   {
#     imports =
#       (import ../../lib/discover-modules.nix { inherit lib; }) ./.
#       ++ [ ../generic/foo.nix ];
#   }
#
# NixOS module merging is order-independent at the options/config layer,
# so dropping the explicit ordering is safe. Use mkBefore/mkAfter or
# priorities if a specific merge order ever becomes load-bearing.
{ lib }:
dir:
let
  entries = builtins.readDir dir;

  isNixFile = name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix";

  isModuleDir = name: type: type == "directory" && builtins.pathExists (dir + "/${name}/default.nix");

  files = lib.mapAttrsToList (name: _: dir + "/${name}") (lib.filterAttrs isNixFile entries);

  dirs = lib.mapAttrsToList (name: _: dir + "/${name}") (lib.filterAttrs isModuleDir entries);
in
files ++ dirs
