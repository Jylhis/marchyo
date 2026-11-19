{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.security.hardening;
  inherit (cfg)
    iommuStrict
    usbguard
    audit
    coredumps
    ;

  hib = config.marchyo.power.hibernation;
  lid = config.marchyo.power.lid;
  lidActions = [
    lid.onBattery
    lid.onAC
    lid.docked
  ];
  kexecLid = lib.filter (a: a == "kexec") lidActions;
  hibernateLid = lib.unique (
    lib.filter (
      a:
      lib.elem a [
        "hibernate"
        "hybrid-sleep"
        "suspend-then-hibernate"
      ]
    ) lidActions
  );
  watchdogOn = config.marchyo.desktop.enable && config.marchyo.desktop.compositorWatch.enable;

  cpuVendors =
    if iommuStrict.vendor != null then
      [ iommuStrict.vendor ]
    else
      lib.optional (config.hardware.cpu.amd.updateMicrocode == true) "amd"
      ++ lib.optional (config.hardware.cpu.intel.updateMicrocode == true) "intel";
  vendorParams = {
    amd = "amd_iommu=force_isolation";
    intel = "intel_iommu=on";
  };

  usbRules = lib.concatStringsSep "\n" (
    lib.optional (
      usbguard.allowedInterfaces != [ ]
    ) "allow with-interface match-all { ${lib.concatStringsSep " " usbguard.allowedInterfaces} }"
    ++ lib.optional (usbguard.rules != "") usbguard.rules
  );

  ipcAcl = pkgs.writeText "usbguard-ipc-acl" ''
    Devices=list,modify,listen
    Policy=list
    Parameters=list
    Exceptions=listen
  '';
  ipcAclDir = "/var/lib/usbguard/IPCAccessControl.d";

  syscallArches = [ "b64" ] ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 "b32";
  defaultAuditRules = [
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/group -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/gshadow -p wa -k identity"
    "-w /etc/sudoers -p wa -k sudoers"
  ]
  ++ lib.concatMap (arch: [
    "-a always,exit -F arch=${arch} -S execve,execveat -C uid!=euid -F euid=0 -F auid>=1000 -F auid!=unset -k priv-esc"
    "-a always,exit -F arch=${arch} -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k modules"
  ]) syscallArches;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.sysctl.enable {
      boot.kernel.sysctl = {
        # nixpkgs sets kptr_restrict to 1 with mkDefault; a second mkDefault
        # with another value would be a conflict.
        "kernel.kptr_restrict" = lib.mkOverride 900 2;
        "kernel.dmesg_restrict" = lib.mkDefault 1;
        "kernel.unprivileged_bpf_disabled" = lib.mkDefault 1;
        "net.core.bpf_jit_harden" = lib.mkDefault 2;
        "net.ipv4.tcp_rfc1337" = lib.mkDefault 1;
        "net.ipv4.conf.all.accept_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.default.accept_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.all.secure_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.default.secure_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.all.send_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.default.send_redirects" = lib.mkDefault 0;
        "net.ipv6.conf.all.accept_redirects" = lib.mkDefault 0;
        "net.ipv6.conf.default.accept_redirects" = lib.mkDefault 0;
      };
    })

    (lib.mkIf (cfg.sysctl.ptraceScope != null) {
      boot.kernel.sysctl."kernel.yama.ptrace_scope" = lib.mkDefault cfg.sysctl.ptraceScope;
    })

    (lib.mkIf (cfg.refuseProtocols != [ ]) {
      boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (
        m: "install ${m} ${lib.getExe' pkgs.coreutils "false"}"
      ) cfg.refuseProtocols;
    })

    (lib.mkIf iommuStrict.enable {
      boot.kernelParams = [
        "iommu.passthrough=0"
        "iommu.strict=1"
      ]
      ++ map (v: vendorParams.${v}) cpuVendors;

      warnings = lib.optional (cpuVendors == [ ] && pkgs.stdenv.hostPlatform.isx86) ''
        marchyo.security.hardening.iommuStrict.enable found no CPU vendor
        (hardware.cpu.amd.updateMicrocode and hardware.cpu.intel.updateMicrocode
        are both unset), so only iommu.passthrough=0 and iommu.strict=1 are added.
        Set marchyo.security.hardening.iommuStrict.vendor.
      '';
    })

    (lib.mkIf usbguard.enable {
      assertions = [
        {
          assertion =
            config.services.usbguard.presentDevicePolicy != "apply-policy"
            || lib.any (lib.hasPrefix "03:") usbguard.allowedInterfaces;
          message = ''
            marchyo.security.hardening.usbguard: with presentDevicePolicy =
            "apply-policy" the devices present at boot are checked against the
            rules, and no allowedInterfaces entry covers human interface devices
            (03:...), so the keyboard can be blocked. Add "03:*:*" (or a
            narrower 03: entry) to allowedInterfaces, or use presentDevicePolicy
            = "keep".
          '';
        }
      ];

      warnings = lib.optional (config.marchyo.security.fido2.enable && usbguard.rules == "") ''
        marchyo.security.fido2.enable and marchyo.security.hardening.usbguard.enable
        are both on and usbguard.rules is empty. A security key that exposes a
        smart-card (CCID) interface next to HID is blocked on hotplug. Add a
        rule for your key to usbguard.rules, for example:
        allow id 1050:0407 with-interface match-all { 03:*:* 0b:00:00 }
        (see "usbguard list-devices" for the id and interfaces).
      '';

      services.usbguard = {
        enable = true;
        presentDevicePolicy = lib.mkDefault usbguard.presentDevicePolicy;
        rules = usbRules;
      };

      systemd.tmpfiles.settings."10-usbguard-ipc" = {
        ${ipcAclDir}.d = {
          mode = "0755";
          user = "root";
          group = "root";
        };
      }
      // lib.genAttrs' usbguard.ipcGroups (g: {
        name = "${ipcAclDir}/:${g}";
        value."L+".argument = "${ipcAcl}";
      });

      systemd.services.usbguard.restartTriggers = [ ipcAcl ];
    })

    (lib.mkIf cfg.protectKernelImage {
      assertions = [
        {
          assertion = !hib.enable && config.boot.resumeDevice == "";
          message = ''
            marchyo.security.hardening.protectKernelImage disables hibernation
            (nohibernate), which conflicts with marchyo.power.hibernation.enable
            and boot.resumeDevice. Turn one of them off.
          '';
        }
        {
          assertion = kexecLid == [ ];
          message = ''
            marchyo.security.hardening.protectKernelImage disables kexec, but
            a marchyo.power.lid action is "kexec". Pick another lid action.
          '';
        }
        {
          assertion = hibernateLid == [ ];
          message = ''
            marchyo.security.hardening.protectKernelImage disables hibernation
            (nohibernate), but a marchyo.power.lid action requests it.
            Found: ${lib.concatStringsSep ", " hibernateLid}. Use "suspend", "lock" or "ignore".
          '';
        }
      ];

      security.protectKernelImage = true;
    })

    (lib.mkIf audit.enable {
      assertions = [
        {
          assertion = config.security.audit.enable != false;
          message = ''
            marchyo.security.hardening.audit.enable needs security.audit.enable,
            which is forced off elsewhere in the configuration.
          '';
        }
      ];

      security = {
        audit = {
          enable = lib.mkDefault true;
          inherit (audit) backlogLimit;
          rules = lib.optionals audit.defaultRules.enable defaultAuditRules ++ audit.extraRules;
        };
        auditd.enable = lib.mkDefault true;
      };
    })

    (lib.mkIf cfg.firewall.enable {
      assertions = [
        {
          assertion = !cfg.firewall.ui.enable || config.marchyo.desktop.enable;
          message = ''
            marchyo.security.hardening.firewall.ui.enable starts the OpenSnitch UI
            for the desktop user and needs marchyo.desktop.enable.
          '';
        }
      ];

      services.opensnitch = {
        enable = true;
        settings.DefaultAction = lib.mkDefault "allow";
      };

      environment.systemPackages = lib.optional config.marchyo.desktop.enable pkgs.opensnitch-ui;
    })

    (lib.mkIf (coredumps != null && coredumps != "none") {
      assertions = [
        {
          assertion = config.systemd.coredump.enable;
          message = ''
            marchyo.security.hardening.coredumps = "${coredumps}" configures
            systemd-coredump, but systemd.coredump.enable is false.
          '';
        }
      ];
    })

    (lib.mkIf (coredumps != null && config.systemd.coredump.enable) {
      # Priority 900 beats the mkDefault in coredump.nix and still yields to a
      # plain definition in the host configuration.
      systemd.coredump.settings.Coredump.Storage = lib.mkOverride 900 coredumps;
    })

    (lib.mkIf (coredumps == "none") {
      warnings = lib.optional watchdogOn ''
        marchyo.security.hardening.coredumps = "none" leaves the compositor
        watchdog (marchyo.desktop.compositorWatch.enable) without the core it
        asks for when Hyprland hangs. Disable the watchdog or pick "external".
      '';

      security.pam.loginLimits = [
        {
          domain = "*";
          item = "core";
          type = "hard";
          value = "0";
        }
      ];
    })
  ];
}
