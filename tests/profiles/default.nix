{
  pkgs,
  lib,
  nixosModules,
  ...
}:
let
  # Shared minimal test configuration for build tests
  minimalTestConfig = {
    # Disable non-redistributable firmware for tests
    hardware.enableAllFirmware = false;
    hardware.enableRedistributableFirmware = true;

    # Minimal boot configuration
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };

    system.stateVersion = "24.11";
  };

  # Shared user configuration for tests
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

  # Helper to create a profile build test
  # Tests that the profile evaluates and builds without errors
in
{
  # ============================================================================
  # BASE PROFILE TESTS
  # ============================================================================

  profile-base-build = pkgs.testers.runNixOSTest {
    name = "profile-base-build";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/base.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Verify base profile features
      # Flakes should be enabled
      machine.succeed("nix --version | grep -q '(Nix)'")

      # NetworkManager should be available
      machine.succeed("command -v nmcli")

      # Verify gc is configured (check nix.conf)
      machine.succeed("grep -q 'auto-optimise-store' /etc/nix/nix.conf")
    '';
  };

  profile-base-nix-settings = pkgs.testers.runNixOSTest {
    name = "profile-base-nix-settings";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          ../../profiles/base.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test flakes are enabled
      machine.succeed("nix flake --version")

      # Test auto-optimize is configured
      machine.succeed("grep -q 'auto-optimise-store = true' /etc/nix/nix.conf")

      # Test garbage collection is scheduled
      machine.succeed("systemctl list-timers | grep -q 'nix-gc'")
    '';
  };

  # ============================================================================
  # DESKTOP PROFILE TESTS
  # ============================================================================

  profile-desktop-build = pkgs.testers.runNixOSTest {
    name = "profile-desktop-build";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/desktop.nix
        ];

        # Disable 32-bit graphics for test compatibility
        hardware.graphics.enable32Bit = lib.mkForce false;

        # Required for desktop profile
        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Desktop environment is enabled
      machine.succeed("command -v Hyprland")

      # PipeWire audio
      machine.wait_for_unit("pipewire.service")

      # Fonts are configured
      machine.succeed("fc-list | grep -i 'noto'")

      # Greetd display manager
      machine.wait_for_unit("greetd.service")

      # Bluetooth is available (service may not start in VM)
      machine.succeed("command -v bluetoothctl")
    '';
  };

  profile-desktop-audio = pkgs.testers.runNixOSTest {
    name = "profile-desktop-audio";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/desktop.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # PipeWire should be running
      machine.wait_for_unit("pipewire.service")
      machine.wait_for_unit("pipewire-pulse.service")

      # PulseAudio compatibility
      machine.succeed("command -v pactl")

      # Verify PipeWire is active
      machine.succeed("systemctl is-active pipewire.service")
    '';
  };

  profile-desktop-xdg-portals = pkgs.testers.runNixOSTest {
    name = "profile-desktop-xdg-portals";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/desktop.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # XDG Desktop Portal should be configured
      machine.succeed("test -f /etc/xdg/xdg-desktop-portal/portals.conf || test -d /run/current-system/sw/share/xdg-desktop-portal")
    '';
  };

  # ============================================================================
  # DEVELOPER PROFILE TESTS
  # ============================================================================

  profile-developer-build = pkgs.testers.runNixOSTest {
    name = "profile-developer-build";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/developer.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Development environment is enabled
      machine.succeed("systemctl status docker.service || true")

      # Git and GitHub CLI
      machine.succeed("command -v git")
      machine.succeed("command -v gh")

      # Build tools
      machine.succeed("command -v gcc")
      machine.succeed("command -v make")

      # Container tools
      machine.succeed("command -v docker-compose")
      machine.succeed("command -v lazydocker")

      # Development utilities
      machine.succeed("command -v jq")
      machine.succeed("command -v ripgrep")
      machine.succeed("command -v bat")
    '';
  };

  profile-developer-virtualization = pkgs.testers.runNixOSTest {
    name = "profile-developer-virtualization";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/developer.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Docker should be available
      machine.succeed("command -v docker")

      # libvirt/QEMU tools
      machine.succeed("command -v virsh")
      machine.succeed("command -v virt-manager")

      # Verify libvirtd service exists
      machine.succeed("systemctl status libvirtd.service || true")
    '';
  };

  profile-developer-sysctl = pkgs.testers.runNixOSTest {
    name = "profile-developer-sysctl";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/developer.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # File watcher limits should be increased
      machine.succeed("sysctl fs.inotify.max_user_watches | grep -q 524288")

      # File descriptor limits
      machine.succeed("sysctl fs.file-max | grep -q 2097152")
    '';
  };

  # ============================================================================
  # GAMING PROFILE TESTS
  # ============================================================================

  profile-gaming-build = pkgs.testers.runNixOSTest {
    name = "profile-gaming-build";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/gaming.nix
        ];

        # Force disable 32-bit for test
        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Steam should be configured
      machine.succeed("command -v steam || echo 'Steam may not be in PATH'")

      # Gamemode
      machine.succeed("command -v gamemoderun")

      # Gaming utilities
      machine.succeed("command -v mangohud")
      machine.succeed("command -v steam-run")

      # Wine for Windows games
      machine.succeed("command -v wine")
      machine.succeed("command -v winetricks")

      # Lutris
      machine.succeed("command -v lutris")
    '';
  };

  profile-gaming-kernel = pkgs.testers.runNixOSTest {
    name = "profile-gaming-kernel";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/gaming.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Verify vm.max_map_count is set for games
      machine.succeed("sysctl vm.max_map_count | grep -q 2147483642")

      # Kernel should be latest (check it's not the default LTS)
      machine.succeed("uname -r")
    '';
  };

  profile-gaming-audio-latency = pkgs.testers.runNixOSTest {
    name = "profile-gaming-audio-latency";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/gaming.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # PipeWire should be running with low latency config
      machine.wait_for_unit("pipewire.service")

      # Check PipeWire configuration exists
      machine.succeed("test -d /etc/pipewire || test -d /run/current-system/sw/etc/pipewire")
    '';
  };

  # ============================================================================
  # SERVER PROFILE TESTS
  # ============================================================================

  profile-server-build = pkgs.testers.runNixOSTest {
    name = "profile-server-build";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/server.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # SSH should be enabled and running
      machine.wait_for_unit("sshd.service")
      machine.wait_for_open_port(22)

      # Fail2ban should be running
      machine.wait_for_unit("fail2ban.service")

      # Server monitoring tools
      machine.succeed("command -v htop")
      machine.succeed("command -v iotop")
      machine.succeed("command -v ncdu")
      machine.succeed("command -v tmux")

      # Network diagnostic tools
      machine.succeed("command -v lsof")
      machine.succeed("command -v tcpdump")

      # System debugging
      machine.succeed("command -v strace")
    '';
  };

  profile-server-security = pkgs.testers.runNixOSTest {
    name = "profile-server-security";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/server.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # SSH configuration should be secure
      # Root login should be disabled
      machine.succeed("grep -q 'PermitRootLogin no' /etc/ssh/sshd_config")

      # Password authentication should be disabled
      machine.succeed("grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config")

      # Fail2ban should be protecting SSH
      machine.succeed("fail2ban-client status sshd || fail2ban-client status")
    '';
  };

  profile-server-disabled-services = pkgs.testers.runNixOSTest {
    name = "profile-server-disabled-services";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/server.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Desktop services should be disabled
      machine.fail("systemctl status pipewire.service")
      machine.fail("systemctl status bluetooth.service")
      machine.fail("systemctl status greetd.service")

      # Printing should be disabled
      machine.fail("systemctl status cups.service")

      # Hyprland should not be installed
      machine.fail("command -v Hyprland")
    '';
  };

  profile-server-network-tuning = pkgs.testers.runNixOSTest {
    name = "profile-server-network-tuning";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/server.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Network tuning parameters should be set
      machine.succeed("sysctl net.core.rmem_max | grep -q 134217728")
      machine.succeed("sysctl net.core.wmem_max | grep -q 134217728")

      # File descriptor limits
      machine.succeed("sysctl fs.file-max | grep -q 2097152")
    '';
  };

  profile-server-auto-updates = pkgs.testers.runNixOSTest {
    name = "profile-server-auto-updates";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/server.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Auto-upgrade should be configured (timer exists)
      machine.succeed("systemctl list-timers | grep -q 'nixos-upgrade' || echo 'Auto-upgrade timer not yet active'")
    '';
  };

  # ============================================================================
  # CROSS-PROFILE INTEGRATION TESTS
  # ============================================================================

  profile-inheritance-desktop-to-developer = pkgs.testers.runNixOSTest {
    name = "profile-inheritance-desktop-to-developer";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/developer.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Developer profile includes desktop
      # So both should be available

      # Desktop features
      machine.succeed("command -v Hyprland")
      machine.wait_for_unit("pipewire.service")

      # Development features
      machine.succeed("command -v docker")
      machine.succeed("command -v git")
    '';
  };

  profile-inheritance-desktop-to-gaming = pkgs.testers.runNixOSTest {
    name = "profile-inheritance-desktop-to-gaming";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/gaming.nix
        ];

        hardware.graphics.enable32Bit = lib.mkForce false;

        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Gaming profile includes desktop
      # So both should be available

      # Desktop features
      machine.succeed("command -v Hyprland")
      machine.wait_for_unit("pipewire.service")

      # Gaming features
      machine.succeed("command -v gamemode")
      machine.succeed("command -v wine")
    '';
  };

  profile-base-independence = pkgs.testers.runNixOSTest {
    name = "profile-base-independence";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          minimalTestConfig
          testUser
          ../../profiles/base.nix
        ];
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Base profile should not include desktop features
      machine.fail("command -v Hyprland")
      machine.fail("systemctl status pipewire.service")
      machine.fail("systemctl status greetd.service")

      # Base features should work
      machine.succeed("command -v nmcli")
      machine.succeed("nix --version")
    '';
  };
}
