# Main test suite entry point
# This file aggregates all tests and exposes them as flake checks
{
  system,
  lib,
  nixpkgs,
  home-manager,
  nixosModules,
  homeModules,
}:
let
  # Create pkgs with unfree allowed for tests
  testPkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # Import test categories
  nixosTests = import ./nixos {
    pkgs = testPkgs;
    inherit lib nixosModules;
  };
  homeTests = import ./home {
    pkgs = testPkgs;
    inherit
      lib
      homeModules
      home-manager
      nixosModules
      ;
  };
  integrationTests = import ./integration {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      homeModules
      home-manager
      ;
  };
  isoTests = import ./isos {
    pkgs = testPkgs;
    inherit
      lib
      nixpkgs
      nixosModules
      system
      ;
  };
  profileTests = import ./profiles {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      homeModules
      home-manager
      ;
  };
  securityTests = import ./security {
    pkgs = testPkgs;
    inherit lib nixosModules;
  };
in
nixosTests // homeTests // integrationTests // isoTests // profileTests // securityTests
