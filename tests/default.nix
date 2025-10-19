# Main test suite entry point
# This file aggregates all tests and separates them into:
# - checks: Lightweight tests that run during `nix flake check` (fast, <1 minute total)
# - vmTests: VM-based tests that must be run manually (slow, 1-5 minutes each)
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

  # Import lightweight tests (fast, no VM required)
  lightweightTests = import ./lightweight {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      homeModules
      home-manager
      ;
  };

  # Import VM-based test categories (slow, VM required)
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

  # Separate VM tests from lightweight integration tests
  vmIntegrationTests = builtins.removeAttrs integrationTests [ "integration-module-eval" ];
  lightweightIntegrationTests = {
    inherit (integrationTests) integration-module-eval;
  };
in
{
  # Lightweight checks that run during `nix flake check`
  # These should complete in under 1 minute total
  checks = lightweightTests // lightweightIntegrationTests;

  # VM-based tests that must be run manually
  # Run with: nix build .#vmTests.x86_64-linux.<test-name>
  vmTests = nixosTests // homeTests // vmIntegrationTests;
}
