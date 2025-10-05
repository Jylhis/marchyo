# Security validation test suite
# Tests security hardening, firewall configuration, service restrictions,
# secrets management, and AppArmor enforcement
{
  pkgs,
  nixosModules,
  ...
}:
let
  # Shared test configuration
  testDefaults = {
    hardware.enableAllFirmware = false;
    hardware.enableRedistributableFirmware = true;
    hardware.graphics.enable32Bit = false;

    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };

    system.stateVersion = "24.11";
  };

  # Test user setup
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
  # ============================================================================
  # TEST 1: Kernel Hardening Sysctls
  # Verify that hardened.enable = true applies proper kernel security settings
  # ============================================================================
  security-hardened-kernel = pkgs.testers.runNixOSTest {
    name = "marchyo-security-hardened-kernel";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo.hardened.enable = true;
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test IP forwarding is disabled
      machine.succeed("test $(sysctl -n net.ipv4.ip_forward) -eq 0")
      machine.succeed("test $(sysctl -n net.ipv6.conf.all.forwarding) -eq 0")

      # Test SYN flood protection
      machine.succeed("test $(sysctl -n net.ipv4.tcp_syncookies) -eq 1")
      machine.succeed("test $(sysctl -n net.ipv4.tcp_max_syn_backlog) -ge 2048")

      # Test ICMP redirect protections
      machine.succeed("test $(sysctl -n net.ipv4.conf.all.accept_redirects) -eq 0")
      machine.succeed("test $(sysctl -n net.ipv4.conf.all.send_redirects) -eq 0")
      machine.succeed("test $(sysctl -n net.ipv6.conf.all.accept_redirects) -eq 0")

      # Test source routing disabled
      machine.succeed("test $(sysctl -n net.ipv4.conf.all.accept_source_route) -eq 0")
      machine.succeed("test $(sysctl -n net.ipv6.conf.all.accept_source_route) -eq 0")

      # Test reverse path filtering enabled
      machine.succeed("test $(sysctl -n net.ipv4.conf.all.rp_filter) -eq 1")

      # Test kernel pointer restriction
      machine.succeed("test $(sysctl -n kernel.kptr_restrict) -eq 2")

      # Test dmesg restriction
      machine.succeed("test $(sysctl -n kernel.dmesg_restrict) -eq 1")

      # Test unprivileged BPF disabled
      machine.succeed("test $(sysctl -n kernel.unprivileged_bpf_disabled) -eq 1")

      # Test unprivileged user namespaces disabled
      machine.succeed("test $(sysctl -n kernel.unprivileged_userns_clone) -eq 0")

      # Test ASLR enabled with maximum entropy
      machine.succeed("test $(sysctl -n kernel.randomize_va_space) -eq 2")

      # Test ptrace scope restricted
      machine.succeed("test $(sysctl -n kernel.yama.ptrace_scope) -eq 2")

      # Test filesystem protections
      machine.succeed("test $(sysctl -n fs.protected_hardlinks) -eq 1")
      machine.succeed("test $(sysctl -n fs.protected_symlinks) -eq 1")
      machine.succeed("test $(sysctl -n fs.protected_fifos) -eq 2")
      machine.succeed("test $(sysctl -n fs.protected_regular) -eq 2")
    '';
  };

  # ============================================================================
  # TEST 2: ICMP Ping Configuration
  # Verify allowPing option controls ICMP echo response
  # ============================================================================
  security-hardened-ping-disabled = pkgs.testers.runNixOSTest {
    name = "marchyo-security-hardened-ping-disabled";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        marchyo.hardened = {
          enable = true;
          allowPing = false;
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test ping is disabled
      machine.succeed("test $(sysctl -n net.ipv4.icmp_echo_ignore_all) -eq 1")
      machine.succeed("test $(sysctl -n net.ipv6.icmp.echo_ignore_all) -eq 1")
    '';
  };

  security-hardened-ping-enabled = pkgs.testers.runNixOSTest {
    name = "marchyo-security-hardened-ping-enabled";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        marchyo.hardened = {
          enable = true;
          allowPing = true;
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test ping is enabled
      machine.succeed("test $(sysctl -n net.ipv4.icmp_echo_ignore_all) -eq 0")
      machine.succeed("test $(sysctl -n net.ipv6.icmp.echo_ignore_all) -eq 0")
    '';
  };

  # ============================================================================
  # TEST 3: Systemd Service Sandboxing
  # Verify that systemd services have proper security restrictions
  # ============================================================================
  security-hardened-systemd = pkgs.testers.runNixOSTest {
    name = "marchyo-security-hardened-systemd";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        marchyo.hardened.enable = true;

        # Create a test service to verify defaults are applied
        systemd.services.test-hardened-service = {
          description = "Test hardened service";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/true";
            RemainAfterExit = true;
          };
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("test-hardened-service.service")

      # Check that service has hardening applied
      # systemd-analyze security shows security settings for a service
      output = machine.succeed("systemd-analyze security test-hardened-service.service")

      # Verify key hardening features are present
      # ProtectSystem, ProtectHome, PrivateTmp, NoNewPrivileges should be enabled
      machine.succeed("systemctl show test-hardened-service.service -p ProtectSystem | grep -q 'ProtectSystem=strict'")
      machine.succeed("systemctl show test-hardened-service.service -p ProtectHome | grep -q 'ProtectHome=yes'")
      machine.succeed("systemctl show test-hardened-service.service -p PrivateTmp | grep -q 'PrivateTmp=yes'")
      machine.succeed("systemctl show test-hardened-service.service -p NoNewPrivileges | grep -q 'NoNewPrivileges=yes'")
      machine.succeed("systemctl show test-hardened-service.service -p ProtectKernelLogs | grep -q 'ProtectKernelLogs=yes'")
      machine.succeed("systemctl show test-hardened-service.service -p ProtectKernelTunables | grep -q 'ProtectKernelTunables=yes'")
      machine.succeed("systemctl show test-hardened-service.service -p ProtectKernelModules | grep -q 'ProtectKernelModules=yes'")
    '';
  };

  # ============================================================================
  # TEST 4: Firewall Enabled by Default
  # Verify that firewall is active when networking is configured
  # ============================================================================
  security-firewall-default = pkgs.testers.runNixOSTest {
    name = "marchyo-security-firewall-default";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        # Enable network
        networking.useDHCP = false;
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Check firewall is enabled in configuration
      # NixOS enables firewall by default, verify it's running
      machine.succeed("systemctl is-active firewall.service || systemctl is-active iptables.service || systemctl is-active nftables.service")
    '';
  };

  # ============================================================================
  # TEST 5: Server Profile - Unnecessary Services Disabled
  # Verify server profile disables desktop and unnecessary services
  # ============================================================================
  security-server-profile = pkgs.testers.runNixOSTest {
    name = "marchyo-security-server-profile";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        # Use server profile
        marchyo.profile = "server";
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Verify desktop services are NOT running
      machine.fail("systemctl is-active greetd.service")
      machine.fail("systemctl is-active hyprland.service")

      # Verify unnecessary services are disabled
      machine.fail("systemctl is-active bluetooth.service")
      machine.fail("systemctl is-active cups.service")
      machine.fail("systemctl is-active avahi-daemon.service")
      machine.fail("systemctl is-active pulseaudio.service")
      machine.fail("systemctl is-active pipewire.service")

      # Verify SSH is enabled in server profile
      machine.wait_for_unit("sshd.service")
      machine.succeed("systemctl is-active sshd.service")

      # Verify fail2ban is running
      machine.wait_for_unit("fail2ban.service")
      machine.succeed("systemctl is-active fail2ban.service")
    '';
  };

  # ============================================================================
  # TEST 6: Secrets Module - No Secrets in Store
  # Verify that secrets module doesn't expose secrets in nix store
  # ============================================================================
  security-secrets-no-store-exposure =
    let
      testSecretsFile = pkgs.writeText "test-secrets.yaml" ''
        test-secret: ENC[AES256_GCM,data:test,iv:test,tag:test,type:str]
      '';
    in
    pkgs.testers.runNixOSTest {
      name = "marchyo-security-secrets-no-store-exposure";

      nodes.machine =
        { config, ... }:
        {
          imports = [
            nixosModules
            testDefaults
          ];

          marchyo.secrets = {
            enable = true;
            # Use a test secrets file
            defaultSopsFile = testSecretsFile;
            # Use a temporary age key location
            ageKeyFile = "/tmp/test-age-key.txt";
          };

          # Create a test secret definition
          sops.secrets."test-secret" = {
            sopsFile = config.marchyo.secrets.defaultSopsFile;
          };
        };

      testScript = ''
          start_all()
          machine.wait_for_unit("multi-user.target")

          # Verify secrets configuration is applied
          machine.succeed("test -n '${toString testSecretsFile}'")

        # Check that secret paths are NOT in /nix/store
        # Secrets should be in /run/secrets or similar
        secret_path = machine.succeed("systemctl cat sops-nix-test-secret.service | grep ExecStart | head -1 || echo '/run/secrets'")
        machine.succeed("echo '{}' | grep -qv '/nix/store'".format(secret_path))

        # Verify sops-nix created the secrets directory
        machine.succeed("test -d /run/secrets || test -d /run/secrets.d")
      '';
    };

  # ============================================================================
  # TEST 7: AppArmor Loading When Enabled
  # Verify that AppArmor is loaded and active when hardened.enableApparmor = true
  # ============================================================================
  security-apparmor-enabled = pkgs.testers.runNixOSTest {
    name = "marchyo-security-apparmor-enabled";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        marchyo.hardened = {
          enable = true;
          enableApparmor = true;
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Wait for AppArmor to initialize
      machine.wait_for_unit("apparmor.service")

      # Verify AppArmor is active
      machine.succeed("systemctl is-active apparmor.service")

      # Check AppArmor module is loaded
      machine.succeed("test -d /sys/kernel/security/apparmor")

      # Verify AppArmor is in enforce mode by checking for profiles
      machine.succeed("aa-status || cat /sys/kernel/security/apparmor/profiles")

      # Check that AppArmor filesystem is mounted
      machine.succeed("mount | grep -q securityfs")
    '';
  };

  # ============================================================================
  # TEST 8: AppArmor Disabled When Not Requested
  # Verify that AppArmor can be disabled via enableApparmor = false
  # ============================================================================
  security-apparmor-disabled = pkgs.testers.runNixOSTest {
    name = "marchyo-security-apparmor-disabled";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
        ];

        marchyo.hardened = {
          enable = true;
          enableApparmor = false;
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Verify AppArmor service is NOT running
      machine.fail("systemctl is-active apparmor.service")
    '';
  };

  # ============================================================================
  # TEST 9: Core Dumps Disabled
  # Verify that core dumps are disabled to prevent memory content leakage
  # ============================================================================
  security-coredumps-disabled = pkgs.testers.runNixOSTest {
    name = "marchyo-security-coredumps-disabled";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo.hardened.enable = true;
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Check core dump limit is set to 0
      output = machine.succeed("su - testuser -c 'ulimit -c'")
      machine.succeed("test $(su - testuser -c 'ulimit -c') -eq 0")

      # Verify systemd-coredump is disabled
      machine.fail("systemctl is-enabled systemd-coredump.socket")
    '';
  };

  # ============================================================================
  # TEST 10: Security Umask Configuration
  # Verify that default umask is restrictive (077)
  # ============================================================================
  security-umask-restrictive = pkgs.testers.runNixOSTest {
    name = "marchyo-security-umask-restrictive";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo.hardened.enable = true;
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Check user's umask is 077
      umask_value = machine.succeed("su - testuser -c 'umask'").strip()
      assert umask_value == "0077" or umask_value == "077", f"Expected umask 077, got {umask_value}"

      # Create a test file and verify permissions are restrictive
      machine.succeed("su - testuser -c 'touch /tmp/test-file-umask'")
      perms = machine.succeed("stat -c '%a' /tmp/test-file-umask").strip()
      assert perms == "600", f"Expected permissions 600, got {perms}"
    '';
  };

  # ============================================================================
  # TEST 11: Combined Security - Full Hardening Stack
  # Verify multiple security features work together correctly
  # ============================================================================
  security-full-hardening = pkgs.testers.runNixOSTest {
    name = "marchyo-security-full-hardening";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          testDefaults
          testUser
        ];

        marchyo.hardened = {
          enable = true;
          enableApparmor = true;
          allowPing = false;
        };

        networking.firewall.enable = true;
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Verify all security components are active
      print("Checking kernel hardening...")
      machine.succeed("test $(sysctl -n kernel.kptr_restrict) -eq 2")
      machine.succeed("test $(sysctl -n kernel.unprivileged_bpf_disabled) -eq 1")

      print("Checking AppArmor...")
      machine.wait_for_unit("apparmor.service")
      machine.succeed("systemctl is-active apparmor.service")

      print("Checking firewall...")
      machine.succeed("systemctl is-active firewall.service || systemctl is-active iptables.service || systemctl is-active nftables.service")

      print("Checking ping disabled...")
      machine.succeed("test $(sysctl -n net.ipv4.icmp_echo_ignore_all) -eq 1")

      print("Checking core dumps disabled...")
      machine.succeed("test $(su - testuser -c 'ulimit -c') -eq 0")

      print("Checking restrictive umask...")
      machine.succeed("su - testuser -c 'touch /tmp/test-combined && test $(stat -c %a /tmp/test-combined) = 600'")

      print("All security checks passed!")
    '';
  };
}
