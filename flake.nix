{
  description = "Marchyo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Nix Cache Route Optimizer, behind marchyo.nix.router.enable.
    ncro = {
      url = "github:manic-systems/ncro";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Base16 schemes, read at eval time as plain data (no IFD).
    tinted-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
    # Declarative partitioning for the disko/ layouts.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://jylhis.cachix.org"
      "https://jylhis-extra.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE="
      "jylhis-extra.cachix.org-1:fG6wVx1e7AaS7vodJoR+0Lk2nhISY3NzGDMAZ2veXKk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      marchyo = import ./outputs.nix { inherit inputs; };
      systems = import ./lib/systems.nix;
      forAllSystems = nixpkgs.lib.genAttrs systems.linux;
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
      checks = forAllSystems (system: marchyo.mkChecks { inherit system; });
      formatter = forAllSystems (system: marchyo.mkFormatter { inherit system; });
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system: marchyo.mkApps { inherit system; });
    };
}
