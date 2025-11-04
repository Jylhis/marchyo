# Auto-generation logic for nixosConfigurations
# Converts flake.marchyo.systems definitions into nixosConfigurations
{ localFlake }:
{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mapAttrs
    filterAttrs
    nixosSystem
    ;
  inherit (localFlake) withSystem;

  cfg = config.flake.marchyo;
  marchyoLib = import ./lib.nix { inherit lib; };
in
{
  config = mkIf (cfg.systems != { }) {
    # Only generate configurations if there are systems defined
    flake.nixosConfigurations =
      let
        # Filter systems that should be auto-generated
        autoGenerateSystems = filterAttrs (_name: systemCfg: systemCfg.autoGenerate) cfg.systems;

        # Generate a single nixosConfiguration from a system definition
        mkSystemOutput =
          name: systemCfg:
          # Use withSystem to access perSystem outputs
          withSystem systemCfg.system (
            { inputs', ... }:
            let
              hostname = marchyoLib.getHostname {
                attrName = name;
                hostnameOverride = systemCfg.hostname;
              };

              # Merge user-provided extraSpecialArgs with automatic inputs'
              specialArgs = marchyoLib.mergeSpecialArgs {
                inherit inputs inputs';
                userArgs = systemCfg.extraSpecialArgs;
              };

              # Get nixosModules from parent flake
              nixosModules = config.flake.nixosModules or { };
              defaultModule = nixosModules.default or null;

              # Automatic hostname module
              hostnameModule = {
                networking.hostName = lib.mkDefault hostname;
              };
            in
            nixosSystem {
              inherit (systemCfg) system;
              modules =
                lib.optionals (defaultModule != null) [ defaultModule ] ++ [ hostnameModule ] ++ systemCfg.modules;
              inherit specialArgs;
            }
          );
      in
      mapAttrs mkSystemOutput autoGenerateSystems;
  };
}
