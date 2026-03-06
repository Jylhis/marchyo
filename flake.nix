{
  description = "Marchyo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
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
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      vicinae,
      noctalia,
      treefmt-nix,
      stylix,
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
                    noctalia
                    vicinae
                    stylix
                    ;
                };
              };
            }
            stylix.nixosModules.stylix

            ./modules/nixos/default.nix
          ];
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

      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixosModules.default
          (
            { lib, ... }:
            {
              networking.hostName = "marchyo-default";
              nixpkgs.overlays = [ overlays ];
              nixpkgs.config.allowUnfree = true;

              # Minimal bootable system
              boot.loader.systemd-boot.enable = lib.mkForce false;
              boot.loader.grub.enable = lib.mkForce false;
              fileSystems."/" = {
                device = "/dev/vda";
                fsType = "ext4";
              };
              system.stateVersion = "25.11";

              # All Marchyo features
              marchyo = {
                desktop.enable = true;
                development.enable = true;
                media.enable = true;
                office.enable = true;
                users.developer = {
                  fullname = "Marchyo Developer";
                  email = "dev@example.org";
                };
              };

              users.users.developer = {
                isNormalUser = true;
                password = "password";
                extraGroups = [
                  "wheel"
                  "networkmanager"
                ];
              };
              services.getty.autologinUser = "developer";
            }
          )
        ];
      };

      overlays.default = overlays;

      legacyPackages = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlays ];
          config.allowUnfree = true;
        }
      );

      inherit (nixpkgs) lib;

      templates = rec {
        default = workstation;
        workstation = {
          path = ./templates/workstation;
          description = "Full developer workstation with desktop and development tools";
        };
      };

      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
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
                    cores = 4;
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
                    users.developer = {
                      fullname = "Marchyo Developer";
                      email = "dev@example.org";
                    };
                  };

                  # User config
                  users.users.developer = {
                    isNormalUser = true;
                    password = "password";
                    extraGroups = [
                      "wheel"
                      "networkmanager"
                    ];
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
            inherit nixpkgs home-manager;
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
