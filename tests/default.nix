# Test suite entry point.
#
# Every `.nix` file under `tests/eval/` is a function of the shared helpers
# (tests/lib.nix) returning an attrset with any of:
#
#   refs.<ref>.<name>        predicate (config -> true | false | message | [ messages ])
#                            run against the shared reference system <ref>
#   refConfig.<ref>          a module merged into the tweakable reference system <ref>
#   variants.<v>             { config; predicates; } for a configuration no other
#                            test shares
#   failing.<name>           { on | system | config; expect; } negative test: an
#                            assertion containing `expect` must fail
#   failingConfig.<sys>      a module merged into the shared failing system <sys>
#   checks.<name>            any other cheap check (a derivation)
#   heavy.<name>             a check that builds something; goes to heavyChecks
#
# Each reference system is evaluated once and becomes ONE check, `ref-<ref>`,
# that runs all its predicates and names every failing one; each variant is
# `variant-<v>`; all negative tests run in `eval-assertions`. Every merge
# throws on a duplicate name instead of letting `//` shadow it.
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

  mergeUnique = import ../lib/merge-unique.nix { inherit lib; };

  baseHelpers = import ./lib.nix {
    pkgs = testPkgs;
    inherit
      lib
      nixosModules
      ;
  };

  # The helpers every file sees, plus `ref <name>`: a fresh evaluation of one
  # reference system, for the heavy checks and for the rare predicate that has
  # to compare two systems (each call is one more evaluation). The systems are
  # built from the files' own refConfig contributions, which is fine as long
  # as no refConfig calls `ref` (laziness keeps the knot untied).
  helpers = baseHelpers // {
    ref = name: (mkRefs null).${name};
  };

  evalFiles = (import ../lib/discover-modules.nix { inherit lib; }) ./eval;

  sections = [
    "refs"
    "refConfig"
    "variants"
    "failing"
    "failingConfig"
    "checks"
    "heavy"
  ];

  files = map (
    f:
    let
      value = import f {
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
      unknown = lib.subtractLists sections (builtins.attrNames value);
    in
    {
      source = toString f;
      value =
        if unknown != [ ] then
          throw "${toString f}: unknown test section(s) ${lib.concatStringsSep ", " unknown} (expected ${lib.concatStringsSep ", " sections})"
        else
          value;
    }
  ) evalFiles;

  section = name: map (f: f // { attrs = f.value.${name} or { }; }) files;

  # Per-name lists of contributions to the systems in `bases`.
  contributions =
    what: bases: pinned:
    lib.zipAttrsWith (_: lib.concatLists) (
      map (
        f:
        lib.mapAttrs (
          name: module:
          if !(bases ? ${name}) then
            throw "${f.source}: ${what}.${name}: no such system (tests/lib.nix)"
          else if lib.elem name pinned then
            throw "${f.source}: ${what}.${name}: '${name}' is pinned to the defaults and takes no ${what}"
          else
            [
              {
                _file = "${f.source} (${what}.${name})";
                imports = [ module ];
              }
            ]
        ) (f.value.${what} or { })
      ) files
    );

  buildSystems =
    bases: extra:
    lib.mapAttrs (
      name: base:
      baseHelpers.mkSystem {
        imports = [ base ] ++ (extra.${name} or [ ]);
      }
    ) bases;

  refContributions = contributions "refConfig" baseHelpers.refBases baseHelpers.pinnedRefs;

  # A fresh, lazily evaluated set of the reference systems. Each check builds
  # its own: an evaluated system is large, and one reachable only from its own
  # check's thunk is garbage once that check is evaluated, instead of staying
  # alive until every check is (one shared set kept them all in memory at
  # once, past what a CI runner has).
  mkRefs = _: buildSystems baseHelpers.refBases refContributions;

  failingContributions = contributions "failingConfig" baseHelpers.failingBases [ ];
  mkFailingSystems = _: buildSystems baseHelpers.failingBases failingContributions;

  # A variant's system, built inside its check for the same reason.
  variantSystem = v: v.system or (baseHelpers.mkSystem v.config);

  # refName -> { predName -> predicate }, merged across files.
  refPredicates = lib.mapAttrs (
    refName: _:
    mergeUnique "predicate (ref-${refName})" (
      map (f: {
        inherit (f) source;
        attrs = (f.value.refs or { }).${refName} or { };
      }) files
    )
  ) baseHelpers.refBases;

  unknownRefs = lib.concatMap (
    f:
    map (r: "${f.source}: refs.${r}") (
      lib.subtractLists (builtins.attrNames baseHelpers.refBases) (
        builtins.attrNames (f.value.refs or { })
      )
    )
  ) files;

  variants = mergeUnique "variant" (section "variants");
  failing = mergeUnique "negative test" (section "failing");

  usedRefs = lib.filterAttrs (_: preds: preds != { }) refPredicates;

  refChecks = lib.mapAttrs' (
    name: preds:
    lib.nameValuePair "ref-${name}" (
      baseHelpers.predicateCheck "ref-${name}" (mkRefs name).${name} preds
    )
  ) usedRefs;

  variantChecks = lib.mapAttrs' (
    name: v:
    lib.nameValuePair "variant-${name}" (
      baseHelpers.predicateCheck "variant-${name}" (variantSystem v) v.predicates
    )
  ) variants;

  libTests = import ./lib-tests.nix {
    inherit lib helpers;
  };

  checks =
    if unknownRefs != [ ] then
      throw "predicates for unknown reference systems: ${lib.concatStringsSep ", " unknownRefs}"
    else
      mergeUnique "check" (
        [
          {
            source = "tests/default.nix (reference systems)";
            attrs = refChecks;
          }
          {
            source = "tests/default.nix (variants)";
            attrs = variantChecks;
          }
          {
            source = "tests/default.nix (negative tests)";
            attrs.eval-assertions =
              baseHelpers.assertionCheck "eval-assertions" (mkFailingSystems null)
                failing;
          }
          {
            source = "tests/lib-tests.nix";
            attrs = libTests;
          }
        ]
        ++ section "checks"
      );

  # One shared set of reference systems, for the debugging outputs below.
  refs = mkRefs null;
in
{
  inherit checks refs;

  heavyChecks = mergeUnique "heavy check" (section "heavy");

  # The unwrapped predicate results, for reading the error a predicate threw
  # (the checks only report that it threw): nix eval
  # .#legacyPackages.<system>.testPredicates.<check>.<predicate>
  predicates =
    lib.mapAttrs' (
      name: preds:
      lib.nameValuePair "ref-${name}" (
        lib.mapAttrs (_: p: baseHelpers.applyPredicate p refs.${name}) preds
      )
    ) usedRefs
    // lib.mapAttrs' (
      name: v:
      let
        system = variantSystem v;
      in
      lib.nameValuePair "variant-${name}" (
        lib.mapAttrs (_: p: baseHelpers.applyPredicate p system) v.predicates
      )
    ) variants;
}
