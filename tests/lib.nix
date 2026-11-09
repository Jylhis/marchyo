# Shared test helpers used by every file under tests/eval/.
{
  pkgs,
  lib,
  nixosModules,
  nix-on-droid,
  home-manager-droid,
  ...
}:
rec {
  # Evaluation-time assertion on a plain value (no NixOS eval). Creates a
  # trivial derivation that fails at eval time if the assertion fails.
  # Uses writeText (no sandbox spawn) instead of runCommand.
  assertTest =
    name: assertion: message:
    pkgs.writeText "test-${name}" (if assertion then "pass" else throw "FAIL: ${name}: ${message}");

  # Verifies a NixOS config evaluates without errors.
  # Forces assertion evaluation (not just stateVersion) to catch real failures.
  testNixOS =
    name: config:
    pkgs.writeText "eval-${name}" (
      let
        eval = lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            config
          ];
        };
        failedAssertions = builtins.filter (x: !x.assertion) eval.config.assertions;
        failedMessages = map (x: x.message) failedAssertions;
      in
      if failedAssertions != [ ] then
        throw "FAIL: ${name}: unexpected assertion failure(s): ${builtins.concatStringsSep "; " failedMessages}"
      else
        builtins.seq eval.config.system.stateVersion "pass"
    );

  # Like testNixOS, but also runs `check eval.config` and fails unless it
  # returns true. Use when a test must inspect *or force* a specific option
  # value — testNixOS only forces `assertions` + `stateVersion`, so lazily
  # evaluated values (boot.kernelParams, security.audit.rules, package lists,
  # generated config text) are otherwise never exercised. The predicate is
  # deep-forced, so referencing a value that throws makes the test fail.
  testNixOSCheck =
    name: check: config:
    pkgs.writeText "eval-${name}" (
      let
        eval = lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            config
          ];
        };
        failedAssertions = builtins.filter (x: !x.assertion) eval.config.assertions;
        failedMessages = map (x: x.message) failedAssertions;
        result = check eval.config;
      in
      if failedAssertions != [ ] then
        throw "FAIL: ${name}: unexpected assertion failure(s): ${builtins.concatStringsSep "; " failedMessages}"
      else if !(builtins.deepSeq result result) then
        throw "FAIL: ${name}: predicate returned false"
      else
        "pass"
    );

  # Verifies a NixOS config triggers an assertion whose message contains
  # `expectedMsg`. Use for negative tests (mutually-exclusive options,
  # required fields, etc.).
  testNixOSFails =
    name: expectedMsg: config:
    pkgs.writeText "eval-fail-${name}" (
      let
        eval = lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            config
          ];
        };
        failedAssertions = builtins.filter (x: !x.assertion) eval.config.assertions;
        failedMessages = map (x: x.message) failedAssertions;
        hasExpectedFailure = lib.any (msg: lib.hasInfix expectedMsg msg) failedMessages;
      in
      if failedAssertions == [ ] then
        throw "FAIL: ${name}: expected assertion failure containing '${expectedMsg}' but all assertions passed"
      else if !hasExpectedFailure then
        throw "FAIL: ${name}: assertion(s) failed but none matched '${expectedMsg}'. Got: ${builtins.concatStringsSep "; " failedMessages}"
      else
        "pass: assertion correctly triggered"
    );

  # Verifies the droid Home-Manager module (modules/nix-on-droid/home.nix)
  # resolves cleanly against nix-on-droid's bundled Home Manager (HM 24.05).
  # This is the real regression risk — the surrounding nix-on-droid system
  # builds via builtins.storePath and so cannot be evaluated in pure mode
  # (nix flake check); the full activation is built impurely via
  # `just build-nix-on-droid`. Forcing hm.config (not activationPackage)
  # resolves every option definition without touching the impure activation.
  testDroidHome =
    name: extraModules:
    pkgs.writeText "eval-droid-${name}" (
      let
        hm = home-manager-droid.lib.homeManagerConfiguration {
          pkgs = import nix-on-droid.inputs.nixpkgs {
            system = "aarch64-linux";
            config.allowUnfree = true;
          };
          modules = [
            ../modules/nix-on-droid/home.nix
            {
              home.username = "nix-on-droid";
              home.homeDirectory = "/data/data/com.termux.nix/files/home";
            }
          ]
          ++ extraModules;
        };
      in
      builtins.seq hm.config.home.stateVersion "pass"
    );

  # Like testDroidHome, but also deep-forces a predicate over the resolved HM
  # config. Use to prove a specific option value (e.g. that a shared generic
  # module activated). The predicate is deep-seq'd, so a value that throws makes
  # the test fail.
  testDroidHomeCheck =
    name: check: extraModules:
    pkgs.writeText "eval-droid-${name}" (
      let
        hm = home-manager-droid.lib.homeManagerConfiguration {
          pkgs = import nix-on-droid.inputs.nixpkgs {
            system = "aarch64-linux";
            config.allowUnfree = true;
          };
          modules = [
            ../modules/nix-on-droid/home.nix
            {
              home.username = "nix-on-droid";
              home.homeDirectory = "/data/data/com.termux.nix/files/home";
            }
          ]
          ++ extraModules;
        };
        result = check hm.config;
      in
      if !(builtins.deepSeq result result) then
        throw "FAIL: ${name}: predicate returned false"
      else
        "pass"
    );

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
}
