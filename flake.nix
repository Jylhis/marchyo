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
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        flakeModules.default = importApply ./modules/flake/default.nix { inherit withSystem; };
        nixosModules = {
          default = {
            imports = [
              inputs.disko.nixosModules.disko
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  extraSpecialArgs = {
                    inherit (inputs) nix-colors;
                    colorSchemes = inputs.nix-colors.colorSchemes // (import ./colorschemes);
                  };
                };
              }
              inputs.determinate.nixosModules.default
              ./modules/nixos/default.nix
            ];
            config._module.args.colorSchemes = inputs.nix-colors.colorSchemes // (import ./colorschemes);
          };
          inherit (inputs.home-manager.nixosModules) home-manager;
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
          # Note: flakeModules.default is for users of marchyo, not for marchyo itself
          # Importing it here would cause infinite recursion
        ];

        perSystem =
          {
            system,
            pkgs,
            lib,
            config,
            ...
          }:
          {
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

            # Import and expose tests
            # Lightweight checks run during `nix flake check`
            checks =
              let
                allTests = import ./tests {
                  inherit system;
                  inherit (inputs.nixpkgs) lib;
                  inherit (inputs) nixpkgs home-manager;
                  nixosModules = nixosModules.default;
                  homeModules = homeModules.default;
                };
              in
              allTests.checks;

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

                # Documentation packages
                docs-options-nixos = import ./docs/build/options-nixos.nix {
                  inherit lib pkgs;
                  nixosModules = nixosModules.default;
                };

                docs-colorschemes = import ./docs/build/colorschemes.nix {
                  inherit lib pkgs;
                  stdenvNoCC = pkgs.stdenvNoCC;
                };

                docs-api = import ./docs/build/api.nix {
                  inherit lib pkgs;
                  stdenvNoCC = pkgs.stdenvNoCC;
                };

                # Combined documentation package
                docs-all = pkgs.runCommand "marchyo-docs-all" { } ''
                  mkdir -p $out/{options-nixos,colorschemes,api}

                  ${pkgs.rsync}/bin/rsync -a ${config.packages.docs-options-nixos}/ $out/options-nixos/
                  ${pkgs.rsync}/bin/rsync -a ${config.packages.docs-colorschemes}/ $out/colorschemes/
                  ${pkgs.rsync}/bin/rsync -a ${config.packages.docs-api}/ $out/api/

                  # Create index.html
                  cat > $out/index.html <<'EOF'
                  <!DOCTYPE html>
                  <html lang="en">
                  <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Marchyo Documentation</title>
                    <style>
                      body { font-family: sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
                      @media (prefers-color-scheme: dark) {
                        body { background: #1a1a1a; color: #e0e0e0; }
                        h1 { color: #e0e0e0; }
                        .description { color: #aaa; }
                      }
                      h1 { color: #333; }
                      ul { list-style: none; padding: 0; }
                      li { margin: 15px 0; }
                      a { color: #0066cc; text-decoration: none; font-size: 1.2em; }
                      a:hover { text-decoration: underline; }
                      .description { color: #666; margin-left: 20px; font-size: 0.95em; }
                    </style>
                  </head>
                  <body>
                    <h1>Marchyo Documentation</h1>
                    <ul>
                      <li>
                        <a href="options-nixos/html/">NixOS Module Options</a>
                        <div class="description">All marchyo.* NixOS configuration options</div>
                      </li>
                      <li>
                        <a href="api/html/">API Reference</a>
                        <div class="description">Library functions and helpers</div>
                      </li>
                      <li>
                        <a href="colorschemes/">Color Schemes</a>
                        <div class="description">Available Base16 color schemes with visual previews</div>
                      </li>
                    </ul>
                  </body>
                  </html>
                  EOF
                '';

                # Development server helper
                docs-serve = pkgs.writeShellScriptBin "docs-serve" ''
                  echo "Building documentation..."
                  DOCS_PATH=$(nix build .#docs-all --no-link --print-out-paths)
                  echo "Documentation built at: $DOCS_PATH"
                  echo "Starting server at http://localhost:8080"
                  echo "Press Ctrl+C to stop"
                  ${pkgs.python3}/bin/python -m http.server 8080 -d "$DOCS_PATH"
                '';
              };
          };

        flake =
          let
            # Import VM tests for all systems
            mkVMTests = system:
              let
                allTests = import ./tests {
                  inherit system;
                  inherit (inputs.nixpkgs) lib;
                  inherit (inputs) nixpkgs home-manager;
                  nixosModules = nixosModules.default;
                  homeModules = homeModules.default;
                };
              in
              allTests.vmTests;
          in
          {
            # inherit flakeModules;
            inherit flakeModules nixosModules homeModules;
            diskoConfigurations = {
              btrfs = ./disko/btrfs.nix;
            };
            overlays.default = import ./overlays { inherit inputs; };
            inherit (inputs.nixpkgs) legacyPackages;
            lib = inputs.nixpkgs.lib // {
              marchyo =
                import ./lib {
                  inherit (inputs.nixpkgs) lib;
                  inherit inputs nixosModules;
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
            # VM tests - slow, resource-intensive tests that don't run during `nix flake check`
            # Run with: nix build .#vmTests.<system>.<test-name>
            vmTests = inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" ] mkVMTests;
          };

      }
    );
}
