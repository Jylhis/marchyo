# Test suite entry point.
# Discovers every `.nix` file under `tests/eval/` and merges the attrsets
# they return. Each eval test file receives shared helpers from `tests/lib.nix`.
#
# Run via `nix flake check` (fast, evaluation-only).
{
  system,
  lib,
  nixpkgs,
  home-manager,
  home-manager-droid,
  nix-on-droid,
  nixosModules,
  homeManagerModules,
}:
let
  testPkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  helpers = import ./lib.nix {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      nix-on-droid
      home-manager-droid
      ;
  };

  evalFiles = (import ../lib/discover-modules.nix { inherit lib; }) ./eval;

  evalTests = lib.foldl' (
    acc: f:
    acc
    // (import f {
      inherit
        helpers
        lib
        home-manager
        nixosModules
        homeManagerModules
        ;
      pkgs = testPkgs;
    })
  ) { } evalFiles;

  libTests = import ./lib-tests.nix {
    pkgs = testPkgs;
    inherit lib;
  };
in
evalTests // libTests
