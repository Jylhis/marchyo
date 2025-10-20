# Main test suite entry point
# Fast evaluation-based tests that run during `nix flake check`
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

  # Import module evaluation tests
  moduleTests = import ./module-tests.nix {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      homeModules
      home-manager
      nix-colors
      ;
  };

  # Import lib function unit tests
  libTests = import ./lib-tests.nix {
    pkgs = testPkgs;
    inherit lib;
  };
in
# Return all checks
moduleTests // libTests
