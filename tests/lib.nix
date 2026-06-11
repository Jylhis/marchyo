# Shared test helpers used by every file under tests/eval/.
{
  pkgs,
  lib,
  nixosModules,
  ...
}:
rec {
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
