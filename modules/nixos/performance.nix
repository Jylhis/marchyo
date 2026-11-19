# Global (headless-safe): CPU mitigations, OOM steering, crash handling,
# MGLRU floor and the flight recorder.
{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo.performance;
  inherit (cfg) oom;
  anchored = names: "^(${lib.concatStringsSep "|" names})$";
  steered = oom.preferProcesses != [ ] || oom.ignoreProcesses != [ ];
  mglruFile = "/sys/kernel/mm/lru_gen/min_ttl_ms";
in
{
  config = lib.mkMerge [
    {
      boot.kernelParams = lib.mkIf cfg.disableMitigations [
        "mitigations=off"
      ];
    }

    (lib.mkIf steered {
      services.earlyoom.extraArgs =
        lib.optionals (oom.preferProcesses != [ ]) [
          "--prefer"
          (anchored oom.preferProcesses)
        ]
        ++ lib.optionals (oom.ignoreProcesses != [ ]) [
          "--ignore"
          (anchored oom.ignoreProcesses)
        ]
        ++ [ "--sort-by-rss" ];
    })

    (lib.mkIf (oom.freeSwapThreshold != null) {
      services.earlyoom.freeSwapThreshold = lib.mkDefault oom.freeSwapThreshold;
    })

    (lib.mkIf (cfg.terminalMemoryLimit != null) {
      systemd.user.units."app-ghostty-surface-transient-.scope" = {
        overrideStrategy = "asDropin";
        text = ''
          [Scope]
          MemoryHigh=${cfg.terminalMemoryLimit.high}
          MemoryMax=${cfg.terminalMemoryLimit.max}
        '';
      };
    })

    (lib.mkIf cfg.crash.panicOnOops {
      boot.kernel.sysctl = {
        "kernel.panic_on_oops" = lib.mkDefault 1;
        "kernel.panic" = lib.mkDefault 10;
      };
    })

    (lib.mkIf (cfg.crash.sysrq != null) {
      boot.kernel.sysctl."kernel.sysrq" = lib.mkDefault cfg.crash.sysrq;
    })

    (lib.mkIf (cfg.mglruMinTtlMs != null) {
      systemd.services.mglru-min-ttl = {
        description = "MGLRU anti-thrash floor";
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = mglruFile;
        script = ''
          echo ${toString cfg.mglruMinTtlMs} > ${mglruFile}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          NoNewPrivileges = true;
          PrivateNetwork = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          # strict leaves /sys writable by root; the write needs no more.
          ProtectSystem = "strict";
          ProtectProc = "invisible";
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = "none";
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "~@resources"
          ];
        };
      };
    })

    (lib.mkIf cfg.flightRecorder.enable {
      services.below = {
        enable = true;
        retention = {
          size = lib.mkDefault (1024 * 1024 * 1024);
          time = lib.mkDefault (7 * 24 * 60 * 60);
        };
      };
    })
  ];
}
