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
    niri = {
      url = "github:sodiboo/niri-flake";
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
      niri,
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
            niri.nixosModules.niri

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
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
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

              users.users.developer.password = "password";
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
            modules = [
              { nixpkgs.hostPlatform = system; }
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
                    qemu.options = [
                      # Niri requires 3D GPU acceleration. Replace QEMU's default
                      # VGA (no 3D) with virtio-vga-gl + OpenGL passthrough.
                      "-vga none"
                      "-device virtio-vga-gl"
                      "-display gtk,gl=on"
                    ];
                  };

                  # Disable Plymouth in VM for visible boot/error output
                  boot.plymouth.enable = false;
                  boot.kernelParams = [ ];
                  boot.consoleLogLevel = 5;
                  boot.initrd.verbose = true;

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
                  users.users.developer.password = "password";
                  services.getty.autologinUser = "developer";

                  # Autologin to niri in the VM
                  services.greetd.settings.initial_session = {
                    command = "niri-session";
                    user = "developer";
                  };

                  system.stateVersion = "25.11";
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
