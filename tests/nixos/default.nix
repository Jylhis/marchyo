{
  pkgs,
  nixosModules,
  lib,
  ...
}:
let
  # Shared test configuration to avoid duplication
  testDefaults = {
    # Disable non-redistributable firmware for tests
    hardware.enableAllFirmware = lib.mkForce false;
    # Disable 32bit graphics on non-x86_64 tests
    hardware.graphics.enable32Bit = false;

    # Minimal boot configuration
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };

    system.stateVersion = "25.11";
  };

  # Shared user configuration
  testUser = {
    users.users.testuser = {
      uid = 1000;
      group = "testuser";
    };
    users.groups.testuser = {
      gid = 1000;
    };
  };
in
{
  # Default VM test - matches the template configuration
  # This represents the minimal working state from templates/workstation
  nixos-default = pkgs.testers.runNixOSTest {
    name = "marchyo-default";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        # Basic marchyo user configuration (same as template)
        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };

        # Allow unfree packages (same as template)
        nixpkgs.config.allowUnfree = true;
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test user exists
      machine.succeed("id testuser")

      # Test git is available (from generic module)
      machine.succeed("command -v git")

      # Test git-lfs is available
      machine.succeed("git lfs version")

      # Test system is functional
      machine.succeed("systemctl status")
    '';
  };
}
