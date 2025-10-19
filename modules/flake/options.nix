# Options for the marchyo flake module
# Defines flake.marchyo.* options for declarative system configuration
{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    mdDoc
    ;
in
{
  options.flake.marchyo = {
    systems = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            system = mkOption {
              type = types.enum [
                "x86_64-linux"
                "aarch64-linux"
                "x86_64-darwin"
                "aarch64-darwin"
              ];
              example = "x86_64-linux";
              description = mdDoc ''
                System architecture for this configuration.
                Must be one of the supported platforms.
              '';
            };

            modules = mkOption {
              type = types.listOf types.unspecified;
              default = [ ];
              example = lib.literalExpression ''
                [
                  ./hardware-configuration.nix
                  { marchyo.desktop.enable = true; }
                ]
              '';
              description = mdDoc ''
                List of NixOS modules to include in this system configuration.
                These modules will be merged with marchyo's default modules.
              '';
            };

            extraSpecialArgs = mkOption {
              type = types.attrsOf types.unspecified;
              default = { };
              example = lib.literalExpression ''
                {
                  myCustomInput = inputs.my-flake;
                  myHostname = "workstation";
                }
              '';
              description = mdDoc ''
                Additional arguments to pass to all modules via specialArgs.
                Note: The 'inputs' attribute is automatically provided and contains
                all flake inputs plus an 'inputs''' (inputs-prime) variant with perSystem packages.
              '';
            };

            hostname = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "workstation";
              description = mdDoc ''
                Optional hostname override for the system.
                If not specified, uses the attribute name from flake.marchyo.systems.
                This value is automatically set in networking.hostName.
              '';
            };

            autoGenerate = mkOption {
              type = types.bool;
              default = true;
              example = false;
              description = mdDoc ''
                Whether to automatically generate a nixosConfiguration for this system.
                Set to false if you want to define the configuration manually
                in flake.nixosConfigurations instead.
              '';
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          workstation = {
            system = "x86_64-linux";
            modules = [
              ./hardware-configuration.nix
              { marchyo.desktop.enable = true; }
            ];
          };
          server = {
            system = "x86_64-linux";
            modules = [ ./server.nix ];
            autoGenerate = false; # Define manually
          };
        }
      '';
      description = mdDoc ''
        Declarative system configurations for marchyo.
        Each attribute defines a system that can be automatically
        converted to a nixosConfiguration.
      '';
    };

    helpers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = mdDoc ''
          Whether to enable helper utilities in perSystem.
          When enabled, provides:
          - marchyo.lib: Extended library functions
          - marchyo.inputs' (inputs-prime): Inputs with perSystem packages
          - marchyo.mkTestVm: Build test VMs for systems
          - marchyo.buildAllSystems: Build all configured systems
        '';
      };
    };
  };
}
