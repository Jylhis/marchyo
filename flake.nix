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
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nix-colors,
      vicinae,
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

      # Define modules
      nixosModules = {
        default = {
          imports = [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                sharedModules = [ vicinae.homeManagerModules.default ];
                extraSpecialArgs = {
                  inherit nix-colors vicinae;
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

      overlays.default = import ./overlays { inherit inputs; };

      inherit (nixpkgs) legacyPackages;

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
