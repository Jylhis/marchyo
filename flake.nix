{
  description = "Marchyo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ncro (Nix Cache Route Optimizer): local HTTP proxy routing binary-cache
    # requests to the fastest reachable upstream. Gated behind
    # marchyo.nix.router.enable.
    ncro = {
      url = "github:manic-systems/ncro";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Base16 scheme catalog (successor of the archived
    # tinted-theming/base16-schemes that pkgs.base16-schemes packages).
    # Pure data source: read at eval time from the fetched tree instead of
    # the built pkgs.base16-schemes package, so evaluation never forces a
    # package build (no import-from-derivation).
    tinted-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      marchyo = import ./outputs.nix { inherit inputs; };
      systems = import ./lib/systems.nix;
      forLinuxSystems = nixpkgs.lib.genAttrs systems.linux;
      forAllSystems = nixpkgs.lib.genAttrs systems.all;
    in
    {
      inherit (marchyo)
        nixosModules
        homeManagerModules
        nixosConfigurations
        homeConfigurations
        overlays
        templates
        lib
        ;
      legacyPackages = forAllSystems marchyo.legacyPackages;
      packages = forAllSystems (system: marchyo.mkPackages { inherit system; });
      checks = forLinuxSystems (system: marchyo.mkChecks { inherit system; });
      formatter = forAllSystems (system: marchyo.mkFormatter { inherit system; });
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system: marchyo.mkApps { inherit system; });
    };
}
