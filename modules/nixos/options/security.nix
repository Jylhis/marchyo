{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  hardening = config.marchyo.security.hardening;
in
{
  options.marchyo.security = {
    fingerprint = {
      enable = lib.mkEnableOption "fingerprint authentication via fprintd (PAM integration is automatic)";
    };

    fido2 = {
      enable = lib.mkEnableOption "FIDO2/U2F hardware security key authentication via pam_u2f";
    };

    ssh = {
      enable = lib.mkEnableOption ''
        the OpenSSH server with key-only authentication: password and
        keyboard-interactive authentication are off and root cannot log in.
        Evaluation fails unless every login user that sshd admits has an
        authorized key, or sshd uses a user CA or an `AuthorizedKeysCommand`
      '';

      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "deploy" ];
        description = ''
          Normal users outside the `wheel` group that also need an authorized
          key. Members of `wheel` are always checked.
        '';
      };

      allowNoKeys = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Skip the authorized-key check, for keys that sshd gets from a place
          evaluation cannot see (for example a key file written at runtime).
        '';
      };
    };

    sudo.timestampTimeout = mkOption {
      type = types.int;
      default = 10;
      example = 0;
      description = ''
        Minutes that sudo remembers a password, written as
        `Defaults timestamp_timeout=<n>`. `0` always asks; a negative value
        never expires.
      '';
    };
    hardening = {
      enable = lib.mkEnableOption ''
        the conservative hardening set: kernel and network sysctls
        (`hardening.sysctl.enable`) and refused legacy network protocols
        (`hardening.refuseProtocols`). Every other switch below is its own
        opt-in and works without this one; none of them is implied by it,
        because each changes daily use. The whole group is independent of
        `marchyo.desktop.enable`
      '';

      sysctl = {
        enable = mkOption {
          type = types.bool;
          default = hardening.enable;
          defaultText = lib.literalExpression "config.marchyo.security.hardening.enable";
          description = ''
            Kernel and network sysctls: `kernel.kptr_restrict = 2`,
            `kernel.dmesg_restrict = 1` (`dmesg` needs root; `journalctl -k`
            still works for the `systemd-journal` group),
            `kernel.unprivileged_bpf_disabled = 1` (the kernel does not allow
            lowering it again until the next reboot), `net.core.bpf_jit_harden = 2`,
            `net.ipv4.tcp_rfc1337 = 1`, and no ICMP redirects accepted or sent
            on IPv4 and IPv6. Unprivileged user namespaces stay on, so browser
            and Flatpak sandboxes keep working. All values are `lib.mkDefault`,
            except `kptr_restrict`: nixpkgs sets it with `lib.mkDefault` too, so
            it uses `lib.mkOverride 900`, which wins over that default and
            still yields to a plain definition in the host configuration.
          '';
        };

        ptraceScope = mkOption {
          type = types.nullOr (
            types.enum [
              0
              1
              2
              3
            ]
          );
          default = null;
          example = 2;
          description = ''
            `kernel.yama.ptrace_scope`. `null` leaves the kernel default (`1`:
            a process may trace only its own descendants). `2` allows only
            `CAP_SYS_PTRACE` holders to attach, so `gdb -p` and `strace -p` on a
            running process need root; `3` forbids tracing entirely and cannot
            be lowered until reboot.
          '';
        };
      };

      refuseProtocols = mkOption {
        type = types.listOf types.str;
        default = lib.optionals hardening.enable [
          "sctp"
          "rds"
          "tipc"
        ];
        defaultText = lib.literalExpression ''
          if config.marchyo.security.hardening.enable then [ "sctp" "rds" "tipc" ] else [ ]
        '';
        description = ''
          Kernel modules that can no longer be loaded (a `modprobe` `install`
          line that runs `false`), so rarely used network protocols cannot be
          reached through a socket call.
        '';
      };

      iommuStrict = {
        enable = lib.mkEnableOption ''
          strict IOMMU isolation with DMA translation: `iommu.passthrough=0`,
          `iommu.strict=1` and the vendor parameter (`amd_iommu=force_isolation`
          or `intel_iommu=on`). Devices behind the IOMMU can no longer read
          arbitrary memory once the kernel has initialised the IOMMU. It gives
          no protection before that point (firmware and boot loader stages) or
          on firmware that publishes no DMAR (Intel) or IVRS (AMD) table, where
          the parameters have no effect. Strict flushing can cost throughput on fast PCIe devices (an
          external GPU, NVMe). It applies at the next boot, so switch to the
          new generation with a boot-only rebuild and keep the previous
          generation in the boot menu as the way back'';

        vendor = mkOption {
          type = types.nullOr (
            types.enum [
              "amd"
              "intel"
            ]
          );
          default = null;
          description = ''
            CPU vendor for the vendor parameter. `null` follows
            `hardware.cpu.amd.updateMicrocode` and
            `hardware.cpu.intel.updateMicrocode` (set by the nixos-hardware CPU
            modules); with neither set, only the two generic parameters are
            added, and on x86_64 evaluation warns.
          '';
        };
      };

      usbguard = {
        enable = lib.mkEnableOption ''
          USBGuard: a USB device that is plugged in after the daemon started
          and matches no rule is blocked. This is not wired into the Marchyo
          shell: there is no on-screen prompt, a device is authorised from a
          terminal with `usbguard list-devices` and `usbguard allow-device <id>`
          by a member of `ipcGroups`. Thunderbolt authorisation (bolt) is
          separate and unaffected'';

        presentDevicePolicy = mkOption {
          type = types.enum [
            "allow"
            "keep"
            "apply-policy"
          ];
          default = "keep";
          description = ''
            How devices already connected when the daemon starts are treated.
            `keep` leaves each device in the state it has: the kernel
            authorised everything that was plugged in at boot, so the keyboard,
            display and network adapters that booted the system keep working,
            and a device that USBGuard blocked earlier stays blocked when the
            daemon restarts. `allow` authorises every present device on each
            daemon start, including one that was blocked. `apply-policy`
            evaluates the rules for present devices too; it needs
            `allowedInterfaces` with an HID entry (`03:`) or `rules`, or a
            reboot can leave the machine without a keyboard.
          '';
        };

        allowedInterfaces = mkOption {
          type = types.listOf types.str;
          default = [
            "03:*:*"
            "09:00:*"
            "e0:01:01"
          ];
          description = ''
            USB interface classes that are always allowed, each written as
            `class:subclass:protocol`. All entries go into one rule,
            `allow with-interface match-all { <entries> }`: a device is
            allowed when every one of its interfaces matches some entry. A
            composite keyboard (two HID interfaces), a Unifying receiver, a
            keyboard with a built-in hub and a hub with several transaction
            translators pass; a device that adds a mass-storage interface to
            an HID one does not. The default allows human interface devices
            (keyboards, mice, security keys without a smart-card interface),
            hubs and Bluetooth adapters, which re-enumerate after a resume, so
            a replugged or resumed input device cannot lock the user out. A
            dock is a hub plus separate devices (Ethernet, audio, display, card
            reader): only the hub passes, the other functions stay blocked when
            hot-plugged until a rule or `usbguard allow-device` admits them. The
            default also lets a hostile keyboard emulator in; drop `03:*:*`
            and list exact devices in `rules` for a stricter policy.
          '';
        };

        rules = mkOption {
          type = types.lines;
          default = "";
          example = "allow id 1050:0407 name \"YubiKey\"";
          description = ''
            Extra rules in the `usbguard-rules.conf(5)` syntax, appended after
            the allowed interfaces. They are managed by Nix and immutable at
            runtime (`usbguard allow-device -p` cannot write them); an
            `allow-device` without `-p` lasts until the device is unplugged.
            With `marchyo.security.fido2.enable`, add a rule for the key: a key
            with an HID and a smart-card (CCID) interface is not allowed by
            `allowedInterfaces`, and evaluation warns when no rule is given.
          '';
        };

        ipcGroups = mkOption {
          type = types.listOf types.str;
          default = [ "wheel" ];
          description = ''
            Groups that may run `usbguard` without being root. Each group gets
            an IPC access-control file with `Devices=list,modify,listen`,
            `Policy=list`, `Parameters=list` and `Exceptions=listen`: its
            members can list devices, authorise or block a device (as a
            temporary state, since the rules are immutable) and watch events.
            They cannot append or remove rules, change daemon parameters or
            stop the policy. A process of such a user can still authorise any
            device without a password, so keep the group small; an empty list
            leaves the `usbguard` command to root.
          '';
        };
      };

      protectKernelImage = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Set `security.protectKernelImage`: hibernation is disabled
          (`nohibernate`) and `kexec_load_disabled` is set, so the running
          kernel cannot be replaced without a reboot. Evaluation fails with
          `marchyo.power.hibernation.enable`, a `boot.resumeDevice`, or a
          `marchyo.power.lid` action that is `kexec`, `hibernate`,
          `hybrid-sleep` or `suspend-then-hibernate`. Kernel modules stay
          loadable, so graphics and other drivers are unaffected; module
          signature enforcement and `kernel.modules_disabled` are not offered
          because they break NVIDIA and out-of-tree modules.
        '';
      };

      audit = {
        enable = lib.mkEnableOption ''
          the Linux audit system and auditd, with the rules below. Records
          go to `/var/log/audit/audit.log` (rotated by auditd) and, as the
          kernel emits them, to the journal. Evaluation fails when
          `security.audit.enable` is forced off elsewhere'';

        defaultRules.enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            The default rules: writes to `/etc/passwd`, `/etc/group`,
            `/etc/shadow`, `/etc/gshadow` (key `identity`) and `/etc/sudoers`
            (key `sudoers`), setuid transitions to root by a logged-in user
            through `execve` or `execveat` (`sudo`, `su`; key `priv-esc`) and
            module loads and unloads by a logged-in user (key `modules`). The
            syscall rules also cover 32-bit syscalls on x86_64. The `auid`
            filters keep boot and daemon activity out.
          '';
        };

        extraRules = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "-w /etc/hosts -p wa -k hosts" ];
          description = ''
            Audit rules, one `auditctl` line each, added after the default
            rules (or alone with `defaultRules.enable = false`).
          '';
        };

        backlogLimit = mkOption {
          type = types.ints.positive;
          default = 8192;
          description = ''
            `audit_backlog_limit`. The kernel holds the records of the whole boot
            (one per unit start and stop) until auditd listens, so the limit has
            to exceed that burst or records are lost.
          '';
        };
      };

      firewall = {
        enable = lib.mkEnableOption ''
          OpenSnitch connection monitoring: the daemon runs with
          `DefaultAction = "allow"` and no rules ship, so the network works
          from the first boot and every connection is logged by the daemon. The
          UI package is installed on a desktop but not started. Rules are
          `services.opensnitch.rules`'';

        ui.enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Start the OpenSnitch UI for every Marchyo user at login (needs
            `marchyo.desktop.enable`). `DefaultAction = "allow"` applies only
            while no UI is connected. Once the UI connects it pushes its own
            default, which is deny: an unmatched connection raises a prompt,
            the prompt times out after 30 seconds with a deny that lasts until
            the daemon restarts, and other new connections are denied while a
            prompt is open. With no rules written, enabling this can cut the
            network, so write rules first. The UI socket is a shared unix
            socket under `/tmp`, so on a multi-user machine one user answers
            the prompts for everyone.
          '';
        };
      };

      coredumps = mkOption {
        type = types.nullOr (
          types.enum [
            "none"
            "journal"
            "external"
          ]
        );
        default = null;
        description = ''
          Where systemd-coredump keeps crashes. `null` leaves the default of
          `modules/nixos/coredump.nix` (`external`, files under
          `/var/lib/systemd/coredump`). `journal` stores them in the journal.
          `none` sets `Storage=none`, so systemd-coredump keeps no core for
          system services, and a hard `core` limit of 0 for login sessions of
          users other than root (PAM limits do not apply to root or to system
          services): the kernel then does not run the core handler for their
          processes at all, so no journal entry or stack trace exists for
          them. `coredumpctl debug` has nothing to open and the core that
          `marchyo-compositor-watch` asks for does not exist; evaluation warns
          when that watchdog is on. With `systemd.coredump.enable = false` only
          the hard limit applies. `journal` and `external` need
          `systemd.coredump.enable`.
        '';
      };
    };
  };
}
