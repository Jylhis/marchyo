{
  description = "Marchyo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      marchyo = import ./outputs.nix { inherit inputs; };
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      allSystems = linuxSystems ++ [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forLinuxSystems = nixpkgs.lib.genAttrs linuxSystems;
      forAllSystems = nixpkgs.lib.genAttrs allSystems;
    in
    {
      inherit (marchyo)
        nixosModules
        darwinModules
        homeManagerModules
        nixosConfigurations
        darwinConfigurations
        homeConfigurations
        overlays
        templates
        ;
      legacyPackages = forAllSystems marchyo.legacyPackages;
      packages = forAllSystems (
        system:
        (nixpkgs.lib.optionalAttrs (builtins.elem system linuxSystems) (
          marchyo.mkPackages { inherit system; }
        ))
        // marchyo.mkDocs { inherit system; }
      );
      checks = forLinuxSystems (system: marchyo.mkChecks { inherit system; });
      formatter = forAllSystems (system: marchyo.mkFormatter { inherit system; });
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system: marchyo.mkApps { inherit system; });
    };
}
