{
  lib,
  inputs ? null,
  nixosModules ? null,
  ...
}:
let
  # Custom wrapper for lib.nixosSystem that automatically includes marchyo modules
  # and provides sensible defaults
  #
  # Benefits:
  # - Reduces boilerplate by automatically including common modules
  # - Enforces consistency across all systems using marchyo
  # - Simplifies configuration for end users
  # - Automatically passes all flake inputs as specialArgs
  #
  # Usage:
  #   nixosConfigurations.myhost = marchyo.lib.mkNixosSystem {
  #     system = "x86_64-linux";
  #     modules = [
  #       ./hardware-configuration.nix
  #       { marchyo.desktop.enable = true; }
  #     ];
  #   };
  mkNixosSystem =
    if inputs == null || nixosModules == null then
      throw "mkNixosSystem requires 'inputs' and 'nixosModules' to be passed to the lib function"
    else
      {
        system,
        modules ? [ ],
        extraSpecialArgs ? { },
      }:
      lib.nixosSystem {
        inherit system;
        modules = [ nixosModules.default ] ++ modules;
        specialArgs = {
          inherit inputs;
        }
        // extraSpecialArgs;
      };
in
{

  mapListToAttrs =
    m: f:
    lib.listToAttrs (
      map (name: {
        inherit name;
        value = f name;
      }) m
    );

  inherit mkNixosSystem;

  colors = import ./colors.nix { inherit lib; };
}
