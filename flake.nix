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
    # flake-compat.url = "github:nix-community/flake-compat";
    # flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "https://flakehub.com/f/nix-community/disko/1.12.0.tar.gz";
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
        nixosModules.default = ./modules/nixos/default.nix;
        homeModules = {
          default = ./modules/home/default.nix;
          _1password = ./modules/home/_1password.nix;
        };
      in
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          inputs.flake-parts.flakeModules.flakeModules
          inputs.disko.flakeModules.default
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
          flakeModules.default
        ];

        perSystem = {
          treefmt = {
            projectRootFile = "flake.nix";

            programs = {
              nixfmt.enable = true;
              actionlint.enable = true;
              deadnix.enable = true;
              shellcheck.enable = true;
              statix.enable = true;
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
        };

        flake = {
          # inherit flakeModules;
          inherit flakeModules nixosModules homeModules;

        };

      }
    );
}
