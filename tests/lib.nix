# Shared test helpers used by every file under tests/eval/.
#
# The suite is built around a few REFERENCE SYSTEMS (`refs` below): NixOS
# configurations that are each evaluated once and shared by every test file.
# A test is a named predicate over one of them, and each reference system
# becomes a single check that runs all of its predicates (see tests/README.md).
# A full `lib.nixosSystem` evaluation with Home Manager costs seconds, so
# sharing one per configuration, instead of evaluating one per test, is what
# keeps `nix flake check` fast.
{
  pkgs,
  lib,
  nixosModules,
  ...
}:
rec {
  # One NixOS evaluation of the marchyo modules plus `module`. Every call is a
  # fresh evaluation, so bind the result once (a let binding or `refs`) and
  # reuse it rather than calling this per test.
  mkSystem =
    module:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        module
      ];
    };

  # The marchyo option declarations alone (modules/nixos/options), without
  # the implementation modules, NixOS or Home Manager: a lib.evalModules call
  # that takes a fraction of a second. Use it for option-level behaviour
  # (types, enums, defaults derived from other marchyo options). Definitions
  # of non-marchyo options (renames, removed-option shims) are accepted and
  # ignored. Returns the evaluated `config`.
  evalOptions =
    module:
    (lib.evalModules {
      modules = [
        ../modules/nixos/options/default.nix
        "${pkgs.path}/nixos/modules/misc/assertions.nix"
        { _module.check = false; }
        module
      ];
      specialArgs = { inherit pkgs; };
    }).config;

  # True when forcing `value` throws (a type error, an enum mismatch, an
  # abort). Only `throw`/`assert` failures are catchable, which is what the
  # module system and lib.types raise.
  throws = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  # A desktop configuration: withTestUser with marchyo.desktop.enable plus
  # `extra`. Home Manager's marchyo modules come in through marchyo.users, so
  # no explicit home-manager import is needed.
  desktopWith = extra: withTestUser (lib.recursiveUpdate { marchyo.desktop.enable = true; } extra);

  # Turn a predicate's result into null (pass) or a failure message.
  # A predicate returns true (pass), false (fail), a string (fail, the string
  # is the message) or a list of failure strings ([ ] = pass).
  predicateVerdict =
    r:
    if r == true then
      null
    else if r == false then
      "returned false"
    else if lib.isString r then
      r
    else if lib.isList r then
      (if r == [ ] then null else lib.concatMapStringsSep "; " toString r)
    else
      "returned a ${builtins.typeOf r}; a predicate must return a bool, a string or a list";

  # `if cond then true else msg`: the usual way to give a failing predicate a
  # message.
  expect = cond: msg: if cond then true else msg;

  # Apply a predicate to an evaluated system. A predicate is `config -> result`,
  # or, when it needs the system's own package set, `{ config, pkgs, ... }:
  # result`.
  applyPredicate =
    pred: system:
    if builtins.functionArgs pred != { } then
      pred {
        inherit (system) config pkgs;
        inherit system;
      }
    else
      pred system.config;

  # Evaluate one predicate against `system`. Thrown errors (throw, assert,
  # module type errors) are caught so every failing predicate is reported;
  # their text is lost to tryEval, so the message points at the unwrapped
  # result exposed under legacyPackages.<system>.testPredicates.
  runPredicate =
    checkName: predName: pred: system:
    let
      attempt = builtins.tryEval (
        let
          r = builtins.addErrorContext "while running test predicate '${predName}' of check '${checkName}'" (
            applyPredicate pred system
          );
        in
        builtins.deepSeq r r
      );
    in
    if attempt.success then
      predicateVerdict attempt.value
    else
      "threw an error; to see it: nix eval .#legacyPackages.${pkgs.stdenv.hostPlatform.system}.testPredicates.${checkName}.${predName}";

  # The check for one system: forces its assertions (an unexpected failed
  # assertion fails the check, as plain `nixos-rebuild` would) and runs every
  # predicate. On failure the message lists every failing predicate by name.
  predicateCheck =
    name: system: predicates:
    let
      failedAssertions = map (a: a.message) (lib.filter (a: !a.assertion) system.config.assertions);
      verdicts = lib.mapAttrs (n: p: runPredicate name n p system) predicates;
      failures =
        lib.filterAttrs (_: v: v != null) verdicts
        // lib.optionalAttrs (failedAssertions != [ ]) {
          "(unexpected failed assertions)" = lib.concatStringsSep "; " failedAssertions;
        };
      count = builtins.length (builtins.attrNames predicates);
    in
    pkgs.writeText name (
      if failures == { } then
        "pass: ${toString count} predicate(s)"
      else
        throw "FAIL: ${name}: ${toString (builtins.length (builtins.attrNames failures))} of ${toString count} predicate(s) failed:\n${
          lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "  - ${n}: ${v}") failures)
        }"
    );

  # The check for the negative tests: each case is a configuration (`on`, the
  # name of a shared failing system below; `system`, an evaluated system; or
  # `config`, a module of its own) that must fail an assertion whose message contains every
  # string in `expect` (one string or a list, all in the same message). Only
  # `config.assertions` is forced (no toplevel), and every failing case is
  # listed by name.
  assertionCheck =
    name: failingSystems: cases:
    let
      verdict =
        caseName: case:
        let
          system =
            if case ? on then
              failingSystems.${case.on}
                or (throw "test case '${caseName}': no failing system '${case.on}' (tests/lib.nix failingBases)")
            else
              case.system or (mkSystem case.config);
          failed = map (a: a.message) (lib.filter (a: !a.assertion) system.config.assertions);
          needles = lib.toList case.expect;
          matches = msg: lib.all (needle: lib.hasInfix needle msg) needles;
          attempt = builtins.tryEval (builtins.deepSeq failed failed);
        in
        if !attempt.success then
          "evaluating the assertions threw instead of failing an assertion"
        else if failed == [ ] then
          "every assertion passed; expected one containing ${lib.concatStringsSep ", " needles}"
        else if !lib.any matches failed then
          "no failed assertion contains all of ${lib.concatStringsSep ", " needles}; got: ${lib.concatStringsSep "; " failed}"
        else
          null;
      failures = lib.filterAttrs (_: v: v != null) (lib.mapAttrs verdict cases);
      count = builtins.length (builtins.attrNames cases);
    in
    pkgs.writeText name (
      if failures == { } then
        "pass: ${toString count} case(s)"
      else
        throw "FAIL: ${name}: ${toString (builtins.length (builtins.attrNames failures))} of ${toString count} case(s) failed:\n${
          lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "  - ${n}: ${v}") failures)
        }"
    );

  # Evaluation-time assertion on a plain value (no NixOS eval). Creates a
  # trivial derivation that fails at eval time if the assertion fails.
  # Uses writeText (no sandbox spawn) instead of runCommand.
  assertTest =
    name: assertion: message:
    pkgs.writeText "test-${name}" (if assertion then "pass" else throw "FAIL: ${name}: ${message}");

  # Flatten a Hyprland Lua settings entry (a bind `{ _args = [...]; }`, a
  # window rule, a monitor spec, ...) into one searchable string, so tests can
  # keep asserting with `hasInfix` the way they did against the old hyprlang
  # strings. mkLuaInline values contribute their raw Lua expression.
  hyprEntryText =
    let
      render =
        v:
        if lib.isAttrs v && (v._type or null) == "lua-inline" then
          v.expr
        else if lib.isAttrs v then
          lib.concatStringsSep " " (lib.mapAttrsToList (k: x: "${k}=${render x}") v)
        else if lib.isList v then
          lib.concatMapStringsSep " " render v
        else if lib.isBool v then
          lib.boolToString v
        else
          toString v;
    in
    render;

  # `hyprEntryText` over a list, joined by newlines.
  hyprEntriesText = entries: lib.concatMapStringsSep "\n" hyprEntryText entries;

  # True when some bind entry is bound to exactly `keys` and its rendered text
  # contains `needle` (the dispatcher expression and/or description). Replaces
  # the old "match the whole hyprlang bind string" assertions.
  hyprHasBind =
    entries: keys: needle:
    lib.any (
      e:
      let
        args = e._args or [ ];
      in
      args != [ ] && builtins.head args == keys && lib.hasInfix needle (hyprEntryText e)
    ) entries;

  # A Lua bind chord in one spelling: modifiers upper-case and sorted, the key
  # lower-case, so "SUPER + SHIFT + CTRL + A" and "SUPER + CTRL + SHIFT + a"
  # compare equal.
  normalizeChord = (import ../lib/hyprland-lua.nix { inherit lib; }).normalizeKeys;

  # Every chord bound more than once across `entries`, minus the `allowed`
  # chords that are bound twice on purpose (a press/release pair, a chained
  # dispatch).
  duplicateChords =
    allowed: entries:
    let
      chords = map normalizeChord (
        lib.filter (c: c != null) (map (e: builtins.head (e._args or [ null ])) entries)
      );
      counts = lib.foldl' (acc: c: acc // { ${c} = (acc.${c} or 0) + 1; }) { } chords;
      dupes = lib.attrNames (lib.filterAttrs (_: n: n > 1) counts);
    in
    lib.subtractLists (map normalizeChord allowed) dupes;

  # Minimal NixOS configuration required for a config to evaluate.
  minimalConfig = {
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };
    system.stateVersion = "25.11";
    nixpkgs.config.allowUnfree = true;
  };

  # Wrap config with a default test user (for modules that require one).
  withTestUser =
    extraConfig:
    lib.recursiveUpdate minimalConfig (
      lib.recursiveUpdate {
        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
        users.users.testuser.uid = 1000;
      } extraConfig
    );

  # The reference systems: name -> base configuration. tests/default.nix
  # evaluates each ONCE, as `base` plus every `refConfig.<name>` module the
  # test files contribute, and runs all of its predicates in the check
  # `ref-<name>`. `helpers.ref <name>` gives a fresh evaluation of one, for
  # the heavy checks and the rare predicate that must compare two systems.
  #
  # The pinned systems (`pinnedRefs`) are the marchyo defaults for one kind of
  # host and take no refConfig: a predicate on `desktop` checks what a plain
  # desktop gets. The others are "tweak" systems that collect non-default
  # settings from many test files. A tweak only belongs on one if it leaves the
  # other predicates there valid; when two tweaks conflict, use another tweak
  # system (or add a numbered one here).
  refBases = {
    # No user, so no Home Manager.
    minimal = minimalConfig;
    minimal-tweaks = minimalConfig;

    headless = withTestUser { };
    headless-tweaks = withTestUser { };
    headless-tweaks-2 = withTestUser { };
    headless-tweaks-3 = withTestUser { };
    headless-tweaks-4 = withTestUser { };

    headless-dev = withTestUser { marchyo.development.enable = true; };
    dev-tweaks = withTestUser { marchyo.development.enable = true; };

    desktop = desktopWith { };
    desktop-shell-off = desktopWith { marchyo.shell.enable = false; };
    desktop-dictation = desktopWith { marchyo.dictation.enable = true; };
    desktop-light = desktopWith { marchyo.theme.variant = "light"; };
    desktop-tweaks = desktopWith { };
    desktop-tweaks-2 = desktopWith { };
    desktop-tweaks-3 = desktopWith { };
    desktop-tweaks-4 = desktopWith { };
    # Opt-outs: every optional desktop feature a test checks the absence of.
    desktop-off = desktopWith { };
    shell-off-tweaks = desktopWith { marchyo.shell.enable = false; };

    # Every feature flag and every bind-contributing feature.
    full = desktopWith {
      marchyo = {
        development.enable = true;
        media.enable = true;
        office.enable = true;
        emacs.enable = true;
        dictation.enable = true;
      };
    };

    # Graphics: one system per GPU layout that several tests share.
    nvidia = minimalConfig // {
      marchyo.graphics.vendors = [ "nvidia" ];
    };
    nvidia-tweaks = withTestUser { };
    prime-offload = minimalConfig // {
      marchyo.graphics = {
        vendors = [
          "intel"
          "nvidia"
        ];
        prime = {
          enable = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
          mode = "offload";
        };
      };
    };
    desktop-amd = desktopWith { marchyo.graphics.vendors = [ "amd" ]; };
    amd-tweaks = withTestUser { };
  };

  pinnedRefs = [
    "minimal"
    "headless"
    "headless-dev"
    "desktop"
    "desktop-shell-off"
    "desktop-dictation"
    "full"
    "nvidia"
    "prime-offload"
    "desktop-amd"
  ];

  # Systems that must FAIL assertions: test files add their misconfiguration
  # with `failingConfig.<name>` and point cases at it with `on = "<name>"`.
  # Each collects unrelated misconfigurations whose assertions are independent,
  # so one evaluation serves many negative tests; every case still names the
  # assertion it expects.
  failingBases = {
    misconfigured = desktopWith { };
    misconfigured-2 = desktopWith { };
    misconfigured-3 = desktopWith { };
    # No user, so no Home Manager: for misconfigurations NixOS alone catches.
    misconfigured-minimal = minimalConfig;
    misconfigured-minimal-2 = minimalConfig;
  };
}
