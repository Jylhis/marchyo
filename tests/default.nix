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
  diskoModule,
  diskoLayout,
  diskoLayouts,
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
      ;
  };

  evalFiles = (import ../lib/discover-modules.nix { inherit lib; }) ./eval;

  mergeUnique = import ../lib/merge-unique.nix { inherit lib; };

  # Merged with mergeUnique, not `//`: two files defining the same test name
  # fail evaluation instead of one silently shadowing the other.
  evalTests = mergeUnique "test" (
    map (f: {
      source = toString f;
      attrs = import f {
        inherit
          helpers
          lib
          home-manager
          nixosModules
          homeManagerModules
          diskoModule
          diskoLayout
          diskoLayouts
          ;
        pkgs = testPkgs;
      };
    }) evalFiles
  );

  libTests = import ./lib-tests.nix {
    inherit lib helpers;
  };
in
mergeUnique "test" [
  {
    source = "tests/eval/";
    attrs = evalTests;
  }
  {
    source = "tests/lib-tests.nix";
    attrs = libTests;
  }
]
