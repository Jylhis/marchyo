# Main test suite entry point
# This file aggregates all lightweight tests that run during `nix flake check`
# Fast tests only - should complete in under 1 minute total
{
  system,
  lib,
  nixpkgs,
  home-manager,
  nix-colors,
  nixosModules,
  homeModules,
}:
let
  # Create pkgs with unfree allowed for tests
  testPkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # Import lightweight tests (fast, no VM required)
  lightweightTests = import ./lightweight {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      homeModules
      home-manager
      nix-colors
      ;
  };

  # Import integration tests (only lightweight check)
  integrationTests = import ./integration {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      homeModules
      home-manager
      nix-colors
      ;
  };
in
# Return only lightweight checks that run during `nix flake check`
lightweightTests // integrationTests
