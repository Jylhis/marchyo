{
  description = "Marchyo";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Disk partitioning tool - imported for future use
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors.url = "github:misterio77/nix-colors";
    # Secrets management with sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        flakeModules.default = importApply ./modules/flake/default.nix { inherit withSystem; };
        nixosModules.default =
          { ... }:
          {
            imports = [
              inputs.sops-nix.nixosModules.sops
              ./modules/nixos/default.nix
            ];
            _module.args = {
              inherit inputs;
            };
          };
        homeModules = {
          default = ./modules/home/default.nix;
          _1password = ./modules/home/_1password.nix;
        };
      in
      {
        systems = [
          "x86_64-linux"
          # "aarch64-linux"
        ];
        imports = [
          inputs.flake-parts.flakeModules.flakeModules
          inputs.disko.flakeModules.default
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
          flakeModules.default
        ];

        perSystem =
          {
            pkgs,
            system,
            ...
          }:
          {
            # Development shell
            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                # Nix development tools
                nil # Nix LSP
                nixd # Alternative Nix LSP
                nixpkgs-fmt # Nix formatter
                alejandra # Alternative Nix formatter
                statix # Nix linter
                deadnix # Find dead Nix code
                nix-tree # Visualize Nix dependencies
                nix-diff # Compare Nix derivations
                nvd # Nix version diff

                # Documentation tools
                mdbook # Documentation generator
                mdbook-mermaid # Mermaid diagrams for mdbook

                # Git tools
                git-cliff # Changelog generator

                # Testing utilities
                nixos-rebuild # For testing configurations

                # Utilities
                jq # JSON processor
                yq # YAML processor
              ];

              shellHook = ''
                echo "🚀 Welcome to Marchyo development environment"
                echo ""
                echo "Available commands:"
                echo "  nix flake check  - Validate flake and run tests"
                echo "  nix fmt          - Format all Nix files"
                echo "  nix build        - Build packages and configurations"
                echo "  nix develop      - Enter development shell (you are here)"
                echo ""
                echo "Useful aliases:"
                echo "  statix check .   - Run Nix linter"
                echo "  deadnix .        - Find dead Nix code"
                echo "  nvd diff         - Compare Nix versions"
                echo "  git-cliff        - Generate changelog"
                echo ""
              '';
            };

            treefmt = {
              projectRootFile = "flake.nix";

              programs = {
                nixfmt.enable = true;
                actionlint.enable = true;
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
            };

            # Import and expose tests as checks
            checks =
              let
                tests = import ./tests {
                  inherit system;
                  inherit (inputs.nixpkgs) lib;
                  inherit (inputs) nixpkgs home-manager;
                  nixosModules = nixosModules.default;
                  homeModules = homeModules.default;
                };
              in
              tests;

            packages =
              let
                installer-minimal =
                  (inputs.nixpkgs.lib.nixosSystem {
                    system = "x86_64-linux";
                    modules = [
                      ./installer/iso-minimal.nix
                    ];
                  }).config.system.build;

                installer-graphical =
                  (inputs.nixpkgs.lib.nixosSystem {
                    system = "x86_64-linux";
                    modules = [
                      ./installer/iso-graphical.nix
                    ];
                  }).config.system.build;
                profile-developer =
                  (inputs.nixpkgs.lib.nixosSystem {
                    system = "x86_64-linux";
                    modules = [
                      { nixpkgs.config.allowUnfree = true; }
                      nixosModules.default
                      ./profiles/developer.nix
                    ];
                  }).config.system.build;

                test-system =
                  (inputs.nixpkgs.lib.nixosSystem {
                    system = "x86_64-linux";
                    modules = [
                      { nixpkgs.config.allowUnfree = true; }
                      nixosModules.default
                      ./disko/btrfs.nix
                      ./profiles/developer.nix
                    ];
                  }).config.system.build.vmWithDisko;
              in
              {
                installer-minimal-iso = installer-minimal.isoImage;
                installer-minimal-vm = installer-minimal.vm;
                installer-graphical-iso = installer-graphical.isoImage;
                installer-graphical-vm = installer-graphical.vm;
                profile-developer-vm = profile-developer.vm;
                inherit test-system;
              };
          };

        flake = {
          # inherit flakeModules;
          inherit flakeModules nixosModules homeModules;
          diskoConfigurations = {
            btrfs = ./disko/btrfs.nix;
          };
          inherit (inputs.nixpkgs) legacyPackages lib;
          templates = rec {
            default = workstation;
            workstation = {
              path = ./templates/workstation;
              description = "Full developer workstation with desktop and development tools";
            };
          };
        };

      }
    );
}
