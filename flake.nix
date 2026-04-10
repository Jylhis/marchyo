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
    inputs@{ nixpkgs, ... }:
    let
      marchyo = import ./default.nix { inherit inputs; };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      inherit (marchyo)
        nixosModules
        homeModules
        nixosConfigurations
        overlays
        lib
        templates
        ;
      legacyPackages = forAllSystems marchyo.legacyPackages;
      checks = forAllSystems (system: marchyo.mkChecks { inherit system; });
      formatter = forAllSystems (system: marchyo.mkFormatter { inherit system; });
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system: marchyo.mkApps { inherit system; });
    };
}
