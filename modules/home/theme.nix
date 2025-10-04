{ lib, ... }@args:
{
  imports = lib.optionals (args ? nix-colors) [
    args.nix-colors.homeManagerModules.default
  ];
}
