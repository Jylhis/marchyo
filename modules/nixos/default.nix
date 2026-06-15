{ lib, ... }:
{
  imports = (import ../../lib/discover-modules.nix { inherit lib; }) ./. ++ [
    ../generic/shell.nix
    ../generic/packages.nix
    ../generic/git.nix
    ../generic/fontconfig.nix
    ../generic/theme.nix
    ../generic/stylix.nix
  ];

  # base16 scheme + fonts live in ../generic/stylix.nix (shared with darwin).
  # NixOS additionally turns stylix on; darwin relies on stylix.autoEnable.
  config.stylix.enable = true;
}
