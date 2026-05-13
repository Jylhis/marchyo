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
