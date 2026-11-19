# SSH hardening, sudo, network sysctls, the kyber I/O scheduler rule and the
# opt-in marchyo.security.hardening group.
# Every reference system that turns marchyo.security.ssh on gives each
# eligible login user a key (or a central source), so its own assertions pass.
{
  lib,
  pkgs,
  nixosModules,
  ...
}:
let
  testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example";

  udevText = c: c.services.udev.extraRules;
  kyberRule =
    c:
    lib.findFirst (l: lib.hasInfix ''ATTR{queue/scheduler}="kyber"'' l) "" (
      lib.splitString "\n" (udevText c)
    );
  sshd = c: c.services.openssh.enable;

  sysctl = c: c.boot.kernel.sysctl;
  params = c: c.boot.kernelParams;
  hasParam = p: c: lib.elem p (params c);
  storage = c: c.systemd.coredump.settings.Coredump.Storage;
  coreLimits = c: lib.filter (l: l.item == "core") c.security.pam.loginLimits;
  rulesText = c: lib.concatStringsSep "\n" c.security.audit.rules;
  hardenedSysctls =
    c:
    let
      s = sysctl c;
    in
    s."kernel.kptr_restrict" == 2
    && s."kernel.dmesg_restrict" == 1
    && s."kernel.unprivileged_bpf_disabled" == 1
    && s."net.core.bpf_jit_harden" == 2
    && s."net.ipv4.tcp_rfc1337" == 1
    && s."net.ipv4.conf.all.accept_redirects" == 0
    && s."net.ipv4.conf.default.accept_redirects" == 0
    && s."net.ipv4.conf.all.secure_redirects" == 0
    && s."net.ipv4.conf.default.secure_redirects" == 0
    && s."net.ipv4.conf.all.send_redirects" == 0
    && s."net.ipv4.conf.default.send_redirects" == 0
    && s."net.ipv6.conf.all.accept_redirects" == 0
    && s."net.ipv6.conf.default.accept_redirects" == 0;

  # The hardened VM: every switch that boots without USB or eBPF hardware.
  vmHardening = {
    marchyo.security.hardening = {
      enable = true;
      protectKernelImage = true;
      audit.enable = true;
      coredumps = "none";
      sysctl.ptraceScope = 2;
      usbguard.enable = true;
    };
  };
  nixosLib = import (pkgs.path + "/nixos/lib") { inherit (pkgs) lib; };
in
{
  refs = {
    headless-tweaks = {
      eval-security-ssh-hardening =
        c:
        let
          s = c.services.openssh.settings;
        in
        c.services.openssh.enable
        && s.PasswordAuthentication == false
        && s.KbdInteractiveAuthentication == false
        && s.PermitRootLogin == "no";

      # Not in wheel, not listed, or no login shell (guest, robot): sshd does not
      # need a key for it.
      eval-security-ssh-ignores-ineligible = sshd;

      # headless-tweaks: marchyo.security.sudo.timestampTimeout = 0.
      eval-security-sudo-timeout-custom =
        c: lib.hasInfix "Defaults timestamp_timeout=0\n" c.security.sudo.extraConfig;
    };

    headless-tweaks-2 = {
      eval-security-ssh-keyfiles = sshd;

      # NVMe tuning owns the NVMe scheduler; kyber keeps the other disks.
      # "none" with systemd-coredump off: no Storage setting, the hard limit
      # still applies.
      eval-hardening-coredumps-none-without-service =
        c:
        !c.systemd.coredump.enable && storage c == "external" && map (l: l.value) (coreLimits c) == [ "0" ];

      eval-security-kyber-rule-nvme-tuned =
        c:
        lib.hasInfix ''KERNEL=="sd*|mmcblk*|vd*"'' (kyberRule c)
        && lib.hasInfix ''ATTR{queue/scheduler}="mq-deadline"'' (udevText c);
    };

    headless-tweaks-3 = {
      eval-security-ssh-ca = sshd;
      eval-security-kyber-rule-off = c: kyberRule c == "";
    };

    headless-tweaks-4.eval-security-ssh-keys-command = sshd;

    dev-tweaks.eval-security-ssh-allow-no-keys = sshd;

    # The check follows sshd itself, not the marchyo flag alone (desktop-off:
    # the flag on, services.openssh.enable forced off).
    desktop-off.eval-security-ssh-sshd-forced-off = c: !(sshd c);

    headless = {
      eval-hardening-off-sysctls =
        c:
        let
          s = sysctl c;
        in
        !(s ? "kernel.dmesg_restrict")
        && !(s ? "kernel.unprivileged_bpf_disabled")
        && !(s ? "net.core.bpf_jit_harden")
        && !(s ? "kernel.yama.ptrace_scope")
        && !(s ? "net.ipv4.conf.all.accept_redirects")
        && s."kernel.kptr_restrict" == 1;

      eval-hardening-off-features =
        c:
        !c.services.usbguard.enable
        && !c.services.opensnitch.enable
        && !c.security.auditd.enable
        && c.security.audit.enable == false
        && !c.security.protectKernelImage
        && !(hasParam "audit=1" c)
        && !(hasParam "nohibernate" c)
        && !(lib.any (lib.hasPrefix "iommu.") (params c))
        && !(lib.hasInfix "install " c.boot.extraModprobeConfig);

      eval-hardening-off-coredump = c: storage c == "external" && coreLimits c == [ ];

      eval-security-ssh-default-off = c: !(sshd c);

      eval-security-sudo-timeout-default =
        c: lib.hasInfix "Defaults timestamp_timeout=10\n" c.security.sudo.extraConfig;

      eval-security-network-sysctls-default =
        c:
        let
          s = c.boot.kernel.sysctl;
        in
        s."net.ipv4.conf.all.arp_ignore" == 1
        && s."net.ipv4.conf.default.arp_ignore" == 1
        && s."net.ipv4.conf.all.arp_announce" == 2
        && s."net.ipv4.conf.default.arp_announce" == 2
        && s."net.ipv4.tcp_mtu_probing" == 1
        && s."net.ipv4.tcp_congestion_control" == "bbr"
        && s."net.core.default_qdisc" == "fq"
        && builtins.elem "tcp_bbr" c.boot.kernelModules;

      eval-security-kyber-rule-default =
        c:
        let
          r = kyberRule c;
        in
        lib.hasInfix ''ENV{DEVTYPE}=="disk"'' r
        && lib.hasInfix ''KERNEL=="nvme*|sd*|mmcblk*|vd*"'' r
        && lib.hasInfix ''ATTR{queue/rotational}=="0"'' r
        && lib.hasInfix ''ATTR{queue/zoned}=="none"'' r
        && !(lib.hasInfix "mq-deadline" (udevText c));
    };

    desktop.eval-hardening-off-firewall-ui =
      c: !c.services.opensnitch.enable && !c.home-manager.users.testuser.services.opensnitch-ui.enable;

    # minimal-tweaks: marchyo.security.hardening.enable only. The conservative
    # set is the sysctls and the refused protocols; nothing else comes with it.
    minimal-tweaks = {
      eval-hardening-enable-sysctls = hardenedSysctls;

      eval-hardening-enable-refused-protocols =
        c:
        lib.all (m: lib.hasInfix "install ${m} " c.boot.extraModprobeConfig) [
          "sctp"
          "rds"
          "tipc"
        ]
        && !(lib.hasInfix "install dccp " c.boot.extraModprobeConfig);

      eval-hardening-enable-implies-nothing-more =
        c:
        !c.services.usbguard.enable
        && !c.services.opensnitch.enable
        && !c.security.auditd.enable
        && !c.security.protectKernelImage
        && !(lib.any (lib.hasPrefix "iommu.") (params c))
        && !(sysctl c ? "kernel.yama.ptrace_scope")
        && storage c == "external";
    };

    # desktop-tweaks: every opt-in switch on, AMD CPU.
    desktop-tweaks = {
      eval-hardening-all-sysctls = c: hardenedSysctls c && (sysctl c)."kernel.yama.ptrace_scope" == 2;

      eval-hardening-all-iommu-amd =
        c:
        hasParam "amd_iommu=force_isolation" c
        && hasParam "iommu.passthrough=0" c
        && hasParam "iommu.strict=1" c
        && !(hasParam "intel_iommu=on" c);

      eval-hardening-all-usbguard =
        c:
        let
          u = c.services.usbguard;
        in
        u.enable
        && u.presentDevicePolicy == "keep"
        && u.implicitPolicyTarget == "block"
        && u.IPCAllowedGroups == [ ]
        && lib.hasInfix "allow with-interface match-all { 03:*:* 09:00:* e0:01:01 }" u.rules
        && !(lib.hasInfix "equals" u.rules)
        && lib.hasInfix "allow id 1050:0407" u.rules;

      eval-hardening-all-usbguard-ipc-acl =
        c:
        let
          t = c.systemd.tmpfiles.settings."10-usbguard-ipc";
        in
        t ? "/var/lib/usbguard/IPCAccessControl.d/:wheel"
        && t."/var/lib/usbguard/IPCAccessControl.d/:wheel" ? "L+"
        && c.systemd.services.usbguard.restartTriggers != [ ];

      eval-hardening-all-kernel-image =
        c:
        c.security.protectKernelImage
        && hasParam "nohibernate" c
        && (sysctl c)."kernel.kexec_load_disabled" == true;

      eval-hardening-all-audit =
        c:
        c.security.audit.enable == true
        && c.security.auditd.enable
        && c.security.audit.backlogLimit == 8192
        && hasParam "audit_backlog_limit=8192" c
        && hasParam "audit=1" c
        && lib.hasInfix "-w /etc/sudoers -p wa -k sudoers" (rulesText c)
        && lib.hasInfix "-C uid!=euid -F euid=0" (rulesText c)
        && lib.hasInfix "-S execve,execveat" (rulesText c)
        && lib.hasInfix "-S init_module,finit_module,delete_module" (rulesText c)
        && lib.hasInfix "arch=b64" (rulesText c)
        && lib.hasInfix "arch=b32" (rulesText c) == pkgs.stdenv.hostPlatform.isx86_64
        && lib.hasInfix "-w /etc/passwd -p wa -k identity" (rulesText c)
        && lib.hasInfix "-k hardening-extra" (rulesText c)
        && lib.hasInfix "-k test-extra" (rulesText c);

      # The UI is installed but not started: with a UI connected the daemon
      # default would no longer be allow.
      eval-hardening-all-firewall =
        c:
        c.services.opensnitch.enable
        && c.services.opensnitch.settings.DefaultAction == "allow"
        && c.services.opensnitch.rules == { }
        && !c.home-manager.users.testuser.services.opensnitch-ui.enable
        && lib.any (p: lib.hasPrefix "opensnitch-ui" p.name) c.environment.systemPackages;

      eval-hardening-all-coredumps-watchdog-warning =
        c:
        lib.any (lib.hasInfix "compositor") c.warnings
        && lib.any (lib.hasInfix "coredumps = \"none\"") c.warnings;

      eval-hardening-all-coredumps-none =
        c:
        storage c == "none"
        &&
          map (l: {
            inherit (l) domain type value;
          }) (coreLimits c) == [
            {
              domain = "*";
              type = "hard";
              value = "0";
            }
          ];
    };

    desktop-tweaks-2.eval-hardening-firewall-ui-opt-in =
      c: c.services.opensnitch.enable && c.home-manager.users.testuser.services.opensnitch-ui.enable;

    # nvidia-tweaks: Intel CPU, coredumps in the journal.
    nvidia-tweaks = {
      eval-hardening-iommu-intel =
        c:
        hasParam "intel_iommu=on" c
        && hasParam "iommu.passthrough=0" c
        && hasParam "iommu.strict=1" c
        && !(hasParam "amd_iommu=force_isolation" c);

      eval-hardening-coredumps-journal = c: storage c == "journal" && coreLimits c == [ ];

      # fido2 and USBGuard without a rule of the user's own.
      eval-hardening-fido2-usbguard-warning =
        c: lib.any (lib.hasInfix "marchyo.security.fido2.enable") c.warnings;
    };

    # amd-tweaks: an explicit vendor beats the detected one.
    amd-tweaks.eval-hardening-iommu-vendor-override =
      c: hasParam "intel_iommu=on" c && !(hasParam "amd_iommu=force_isolation" c);

    # headless-tweaks-4: no CPU vendor to go by.
    headless-tweaks-4 = {
      eval-hardening-iommu-no-vendor =
        c:
        hasParam "iommu.strict=1" c
        && !(hasParam "intel_iommu=on" c)
        && !(hasParam "amd_iommu=force_isolation" c)
        && lib.any (lib.hasInfix "found no CPU vendor") c.warnings == pkgs.stdenv.hostPlatform.isx86;

      eval-hardening-coredumps-external = c: storage c == "external" && coreLimits c == [ ];
    };

    # headless-tweaks-3: a stricter USBGuard policy and a shorter protocol list.
    headless-tweaks-3 = {
      eval-hardening-usbguard-custom =
        c:
        let
          u = c.services.usbguard;
        in
        u.enable
        && u.presentDevicePolicy == "allow"
        && u.rules == "allow id 1050:0407"
        && u.IPCAllowedGroups == [ ]
        && c.systemd.tmpfiles.settings."10-usbguard-ipc" ? "/var/lib/usbguard/IPCAccessControl.d/:plugdev";

      # Defaults off and extraRules alone, through the marchyo option.
      eval-hardening-audit-extra-rules-only =
        c: c.security.audit.rules == [ "-w /etc/hosts -p wa -k only-extra" ];

      eval-hardening-refuse-protocols-custom =
        c:
        lib.hasInfix "install sctp " c.boot.extraModprobeConfig
        && !(lib.hasInfix "install dccp " c.boot.extraModprobeConfig)
        && !(sysctl c ? "kernel.dmesg_restrict");
    };
  };

  refConfig = {
    headless-tweaks = {
      marchyo.security.ssh.enable = true;
      marchyo.security.sudo.timestampTimeout = 0;
      users.users = {
        testuser.openssh.authorizedKeys.keys = [ testKey ];
        guest = {
          isNormalUser = true;
          group = "users";
        };
        robot = {
          isNormalUser = true;
          group = "users";
          extraGroups = [ "wheel" ];
          shell = "/run/current-system/sw/bin/nologin";
        };
      };
    };
    headless-tweaks-2 = {
      marchyo.security.ssh.enable = true;
      users.users.testuser.openssh.authorizedKeys.keyFiles = [ ./fixtures/ssh-test.pub ];
      systemd.coredump.enable = false;
      marchyo.security.hardening.coredumps = "none";
    };
    headless-tweaks-3 = {
      marchyo.security.ssh.enable = true;
      services.openssh.settings.TrustedUserCAKeys = "/etc/ssh/user_ca.pub";
      marchyo.performance.kyber.enable = false;
    };
    headless-tweaks-4 = {
      marchyo.security.ssh.enable = true;
      services.openssh.authorizedKeysCommand = "/run/current-system/sw/bin/true";
    };
    dev-tweaks.marchyo.security.ssh = {
      enable = true;
      allowNoKeys = true;
    };
    desktop-off = {
      marchyo.security.ssh.enable = true;
      services.openssh.enable = lib.mkForce false;
    };

    minimal-tweaks.marchyo.security.hardening.enable = true;
    desktop-tweaks = {
      hardware.cpu.amd.updateMicrocode = true;
      marchyo.security.hardening = {
        enable = true;
        iommuStrict.enable = true;
        usbguard = {
          enable = true;
          rules = ''allow id 1050:0407 name "YubiKey"'';
        };
        protectKernelImage = true;
        audit = {
          enable = true;
          extraRules = [ "-w /etc/hardening -p wa -k hardening-extra" ];
        };
        firewall.enable = true;
        coredumps = "none";
        sysctl.ptraceScope = 2;
      };
      security.audit.rules = lib.mkAfter [ "-w /etc/hosts -p wa -k test-extra" ];
    };
    nvidia-tweaks = {
      hardware.cpu.intel.updateMicrocode = true;
      marchyo.security.fido2.enable = true;
      marchyo.security.hardening = {
        iommuStrict.enable = true;
        coredumps = "journal";
        usbguard.enable = true;
      };
    };
    desktop-tweaks-2.marchyo.security.hardening.firewall = {
      enable = true;
      ui.enable = true;
    };
    amd-tweaks = {
      hardware.cpu.amd.updateMicrocode = true;
      marchyo.security.hardening.iommuStrict = {
        enable = true;
        vendor = "intel";
      };
    };
    headless-tweaks-4.marchyo.security.hardening = {
      iommuStrict.enable = true;
      coredumps = "external";
    };
    headless-tweaks-3.marchyo.security.hardening = {
      usbguard = {
        enable = true;
        presentDevicePolicy = "allow";
        allowedInterfaces = [ ];
        rules = "allow id 1050:0407";
        ipcGroups = [ "plugdev" ];
      };
      audit = {
        enable = true;
        defaultRules.enable = false;
        extraRules = [ "-w /etc/hosts -p wa -k only-extra" ];
      };
      refuseProtocols = [ "sctp" ];
    };
  };

  failing = {
    # testuser is in wheel (marchyo.users) and has no key (misconfigured).
    eval-security-ssh-requires-keys = {
      on = "misconfigured";
      expect = "authorized SSH key: testuser.";
    };

    # A user listed in marchyo.security.ssh.users (deploy) and a wheel member
    # (ops) without keys are both reported (misconfigured-2). (Merges the
    # former eval-security-ssh-listed-user-requires-keys and
    # eval-security-ssh-primary-wheel-requires-keys.)
    eval-security-ssh-listed-and-wheel-users-require-keys = {
      on = "misconfigured-2";
      expect = "authorized SSH key: deploy, ops.";
    };

    # "none" switches the CA or command off, so keys are still required
    # (misconfigured-3).
    eval-security-ssh-none-ca-requires-keys = {
      on = "misconfigured-3";
      expect = "authorized SSH key: testuser.";
    };

    eval-hardening-kernel-image-vs-hibernation = {
      on = "misconfigured-2";
      expect = "protectKernelImage disables hibernation";
    };

    eval-hardening-kernel-image-vs-kexec-lid = {
      on = "misconfigured-3";
      expect = "a marchyo.power.lid action is \"kexec\"";
    };

    eval-hardening-kernel-image-vs-hibernate-lid = {
      on = "misconfigured";
      expect = "Found: hibernate, hybrid-sleep, suspend-then-hibernate.";
    };

    eval-hardening-audit-forced-off = {
      on = "misconfigured-3";
      expect = "audit.enable needs security.audit.enable";
    };

    eval-hardening-coredumps-need-coredump-service = {
      on = "misconfigured";
      expect = "systemd.coredump.enable is false";
    };

    eval-hardening-usbguard-apply-policy-needs-hid = {
      on = "misconfigured";
      expect = "no allowedInterfaces entry covers human interface devices";
    };

    eval-hardening-firewall-ui-needs-desktop = {
      on = "misconfigured-minimal";
      expect = "firewall.ui.enable starts the OpenSnitch UI";
    };
  };

  failingConfig = {
    misconfigured = {
      marchyo.security.ssh.enable = true;
      systemd.coredump.enable = false;
      marchyo.power.lid = {
        onBattery = "hibernate";
        onAC = "hybrid-sleep";
        docked = "suspend-then-hibernate";
      };
      marchyo.security.hardening = {
        coredumps = "journal";
        protectKernelImage = true;
        usbguard = {
          enable = true;
          presentDevicePolicy = "apply-policy";
          allowedInterfaces = [ "09:00:*" ];
        };
      };
    };
    misconfigured-2 = {
      marchyo.security.hardening.protectKernelImage = true;
      marchyo.power.hibernation.enable = true;
      swapDevices = [ { device = "/dev/vda2"; } ];
      marchyo.security.ssh.enable = true;
      marchyo.security.ssh.users = [ "deploy" ];
      users.users = {
        testuser.openssh.authorizedKeys.keys = [ testKey ];
        deploy = {
          isNormalUser = true;
          group = "users";
        };
        ops = {
          isNormalUser = true;
          group = "wheel";
        };
      };
    };
    misconfigured-3 = {
      marchyo.security.hardening.protectKernelImage = true;
      marchyo.power.lid.onAC = "kexec";
      marchyo.security.hardening.audit.enable = true;
      security.audit.enable = lib.mkForce false;
      marchyo.security.ssh.enable = true;
      services.openssh.settings.TrustedUserCAKeys = "none";
      services.openssh.settings.AuthorizedKeysCommand = "none";
    };
    misconfigured-minimal.marchyo.security.hardening.firewall = {
      enable = true;
      ui.enable = true;
    };
  };

  heavy.build-security-hardening-vm = nixosLib.runTest {
    name = "marchyo-security-hardening";
    hostPkgs = pkgs;

    nodes.machine = {
      imports = [
        nixosModules
        vmHardening
      ];

      nixpkgs.config.allowUnfree = true;

      users.users.alice = {
        isNormalUser = true;
        initialPassword = "secret";
        extraGroups = [ "wheel" ];
      };
      security.sudo.wheelNeedsPassword = false;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      sysctls = {
          "kernel.kptr_restrict": "2",
          "kernel.dmesg_restrict": "1",
          "kernel.unprivileged_bpf_disabled": "1",
          "net.core.bpf_jit_harden": "2",
          "net.ipv4.conf.all.accept_redirects": "0",
          "net.ipv6.conf.default.accept_redirects": "0",
          "kernel.yama.ptrace_scope": "2",
          "kernel.kexec_load_disabled": "1",
      }
      for key, want in sysctls.items():
          got = machine.succeed(f"sysctl -n {key}").strip()
          assert got == want, f"{key} is {got}, expected {want}"

      cmdline = machine.succeed("cat /proc/cmdline")
      assert "nohibernate" in cmdline, cmdline
      assert "audit=1" in cmdline, cmdline

      machine.wait_for_unit("auditd.service")
      machine.wait_for_unit("audit-rules-nixos.service")
      machine.succeed("systemctl is-active auditd")
      status = machine.succeed("auditctl -s")
      assert "enabled 1" in status, status
      rules = machine.succeed("auditctl -l")
      for key in ("identity", "sudoers", "priv-esc", "modules"):
          assert f"-k {key}" in rules or f"key={key}" in rules, f"audit rule {key} not loaded: {rules}"
      assert rules.count("priv-esc") == 2, rules
      assert "arch=b32" in rules and "execveat" in rules, rules

      machine.fail("runuser -u nobody -- dmesg")
      machine.succeed("find -L /run/booted-system/kernel-modules/lib/modules -name 'sctp.ko*' | grep -q .")
      machine.succeed("modprobe dummy")
      machine.fail("modprobe sctp")
      machine.fail("grep -q '^sctp ' /proc/modules")

      machine.wait_for_unit("usbguard.service")
      machine.succeed("runuser -u alice -- usbguard list-devices")
      machine.succeed("runuser -u alice -- usbguard list-rules | grep -q 'match-all'")
      machine.fail("runuser -u alice -- usbguard set-parameter InsertedDevicePolicy block")
      machine.fail("runuser -u alice -- usbguard append-rule 'allow'")
      machine.succeed("usbguard set-parameter InsertedDevicePolicy apply-policy")
      machine.succeed("grep -E '^\\*[[:space:]]+hard[[:space:]]+core[[:space:]]+0' $(grep -o 'conf=[^ ]*' /etc/pam.d/login | head -1 | cut -d= -f2)")

      machine.wait_until_tty_matches("1", "login: ")
      machine.send_chars("alice\n")
      machine.wait_until_tty_matches("1", "Password: ")
      machine.send_chars("secret\n")
      machine.wait_until_succeeds("pgrep -u alice -x bash")
      machine.send_chars("sudo true\n")
      machine.wait_until_succeeds("ausearch -k priv-esc")

      count = "journalctl -b -q --no-pager -o cat _TRANSPORT=audit | wc -l"
      before = int(machine.succeed(count))
      machine.sleep(5)
      idle = int(machine.succeed(count)) - before
      assert idle < 20, f"{idle} audit records in 5 idle seconds"
    '';
  };
}
