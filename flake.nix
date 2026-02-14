{
  description = "Marchyo";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    treefmt-nix = {
      url = "https://flakehub.com/f/numtide/treefmt-nix/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors = {
      url = "github:misterio77/nix-colors";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    worktrunk = {
      url = "github:max-sixty/worktrunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nix-colors,
      vicinae,
      noctalia,
      worktrunk,
      treefmt-nix,
      determinate,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Helper to generate per-system outputs
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Import overlays
      overlays = import ./overlays { inherit inputs; };

      # Define modules
      nixosModules = {
        default = {
          imports = [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                sharedModules = [
                  noctalia.homeModules.default
                  vicinae.homeManagerModules.default
                ];
                extraSpecialArgs = {
                  inherit
                    nix-colors
                    noctalia
                    vicinae
                    worktrunk
                    ;
                  colorSchemes = nix-colors.colorSchemes // (import ./colorschemes);
                };
              };
            }
            determinate.nixosModules.default
            ./modules/nixos/default.nix
          ];
          config._module.args.colorSchemes = nix-colors.colorSchemes // (import ./colorschemes);
        };
        inherit (home-manager.nixosModules) home-manager;
      };

      homeModules = {
        default = ./modules/home/default.nix;
        _1password = ./modules/home/_1password.nix;
      };
    in
    {
      # Flake-level outputs (not per-system)
      inherit nixosModules homeModules;

      overlays.default = overlays;

      legacyPackages = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlays ];
          config.allowUnfree = true;
        }
      );

      lib = nixpkgs.lib // {
        marchyo =
          import ./lib {
            inherit (nixpkgs) lib;
          }
          // {
            colorSchemes = import ./colorschemes;
          };
      };

      templates = rec {
        default = workstation;
        workstation = {
          path = ./templates/workstation;
          description = "Full developer workstation with desktop and development tools";
        };
      };

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          vm = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              nixosModules.default
              (
                {
                  lib,
                  modulesPath,
                  ...
                }:
                {
                  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

                  # Set hostname first so it's available for script name
                  networking.hostName = "marchyo-vm";

                  # Apply overlays
                  nixpkgs.overlays = [ overlays ];
                  nixpkgs.config.allowUnfree = true;

                  # VM Specs
                  virtualisation = {
                    memorySize = 4096;
                    cores = 2;
                    graphics = true;
                  };

                  # Bootloader fix
                  boot.loader.systemd-boot.enable = lib.mkForce false;

                  # Marchyo Features
                  marchyo = {
                    desktop.enable = true;
                    development.enable = true;
                    media.enable = true;
                    office.enable = true;
                  };

                  # User config
                  users.users.developer = {
                    isNormalUser = true;
                    password = "password";
                    extraGroups = [
                      "wheel"
                      "networkmanager"
                    ];
                    description = "Marchyo Developer";
                  };
                  services.getty.autologinUser = "developer";
                }
              )
            ];
          };
          runner = pkgs.writeShellScriptBin "run-vm" ''
            exec ${vm.config.system.build.vm}/bin/run-${vm.config.networking.hostName}-vm "$@"
          '';
        in
        {
          default = {
            type = "app";
            program = "${runner}/bin/run-vm";
          };
        }
      );

      # Per-system outputs
      checks = forAllSystems (
        system:
        let
          allTests = import ./tests {
            inherit system;
            inherit (nixpkgs) lib;
            inherit nixpkgs home-manager nix-colors;
            nixosModules = nixosModules.default;
            homeModules = homeModules.default;
          };
        in
        allTests
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        treefmt-nix.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";

          programs = {
            nixfmt.enable = true;
            actionlint.enable = false;
            deadnix.enable = true;
            shellcheck.enable = true;
            statix.enable = true;
            yamlfmt.enable = true;
          };
          settings.formatter.shellcheck = {
            excludes = [
              "**/.envrc"
              ".envrc"
            ];
            options = [
              "-s"
              "bash"
            ];
          };
        }
      );
    };
}
