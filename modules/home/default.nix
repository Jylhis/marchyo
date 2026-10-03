{ lib, ... }:
{
  imports = (import ../../lib/discover-modules.nix { inherit lib; }) ./. ++ [
    ../generic/fontconfig.nix
    ../generic/git.nix
    ../generic/shell.nix
    ../generic/packages.nix
  ];
}
