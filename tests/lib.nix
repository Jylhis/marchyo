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
