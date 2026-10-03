{ lib, ... }:
{
  imports = (import ../../lib/discover-modules.nix { inherit lib; }) ./. ++ [
    ../generic/shell.nix
    ../generic/packages.nix
    ../generic/git.nix
    ../generic/fontconfig.nix
  ];
}
