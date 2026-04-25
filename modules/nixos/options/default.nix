{ lib, ... }:
{
  imports = (import ../../../lib/discover-modules.nix { inherit lib; }) ./.;
}
