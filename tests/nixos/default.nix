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
      isNormalUser = true;
      uid = 1000;
      group = "testuser";
    };
    users.groups.testuser = {
      gid = 1000;
    };
  };
in
{
  # Desktop environment test
  nixos-desktop = pkgs.testers.runNixOSTest {
    name = "marchyo-desktop";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo = {
          desktop.enable = true;
          users.testuser = {
            enable = true;
            fullname = "Test User";
            email = "test@example.com";
          };
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test Hyprland is installed
      machine.succeed("command -v Hyprland")

      # Test fonts are configured
      machine.succeed("fc-list | grep -i 'noto'")

      # Test greetd is running
      machine.wait_for_unit("greetd.service")
    '';
  };

  # Development tools test
  nixos-development = pkgs.testers.runNixOSTest {
    name = "marchyo-development";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo = {
          development.enable = true;
          users.testuser = {
            enable = true;
            fullname = "Test User";
            email = "test@example.com";
          };
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test Docker is available
      machine.succeed("command -v docker")

      # Test GitHub CLI is available
      machine.succeed("command -v gh")

      # Test buildah is available
      machine.succeed("command -v buildah")
    '';
  };

  # User configuration test
  nixos-users = pkgs.testers.runNixOSTest {
    name = "marchyo-users";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        marchyo.users = {
          alice = {
            enable = true;
            fullname = "Alice Smith";
            email = "alice@example.com";
          };
          bob = {
            enable = true;
            fullname = "Bob Jones";
            email = "bob@example.com";
          };
        };

        # Actually create the users
        users.users = {
          alice = {
            isNormalUser = true;
            uid = 1000;
            group = "alice";
          };
          bob = {
            isNormalUser = true;
            uid = 1001;
            group = "bob";
          };
        };

        users.groups = {
          alice.gid = 1000;
          bob.gid = 1001;
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test that marchyo user options are properly defined
      # and users are created
      machine.succeed("id alice")
      machine.succeed("id bob")
      machine.succeed("systemctl status")
    '';
  };

  # Git configuration test
  nixos-git = pkgs.testers.runNixOSTest {
    name = "marchyo-git";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test git is installed (from generic module)
      machine.succeed("command -v git")

      # Test git-lfs is available
      machine.succeed("git lfs version")
    '';
  };
}
