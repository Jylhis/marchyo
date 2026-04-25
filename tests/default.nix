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
    inherit lib nixosModules;
  };

  evalDir = ./eval;
  evalFiles = lib.mapAttrsToList (name: _: evalDir + "/${name}") (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
      builtins.readDir evalDir
    )
  );

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
