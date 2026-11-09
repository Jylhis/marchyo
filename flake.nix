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
    # nix-on-droid (Android terminal). Pinned to the latest prerelease with a
    # dedicated home-manager input matching it (the prerelease expects HM 24.05).
    # Kept internally consistent on its own bundled nixpkgs (NOT following the
    # unstable primary), so the droid HM config stays on HM-24.05 semantics.
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/prerelease-25.11";
      inputs.home-manager.follows = "home-manager-droid";
    };
    # Pinned to the exact home-manager revision nix-on-droid prerelease-25.11
    # bundles, so it matches that branch's (2024-era) nixpkgs lib. Using
    # release-24.05 HEAD instead breaks: its kanshi.nix needs lib.types.attrTag,
    # absent from the bundled nixpkgs.
    home-manager-droid = {
      url = "github:nix-community/home-manager/4de84265d7ec7634a69ba75028696d74de9a44a7";
      inputs.nixpkgs.follows = "nix-on-droid/nixpkgs";
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
        nixOnDroidModules
        nixosConfigurations
        homeConfigurations
        nixOnDroidConfigurations
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
