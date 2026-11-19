{ lib, ... }:
{
  refs = {
    # tuning.enable turns on the broadly-safe sub-toggles (network/nvme/memory)
    # (headless-tweaks-2).
    headless-tweaks-2.eval-performance-tuning-default = c: c.marchyo.performance.tuning.enable;

    # Mitigations stay on by default.
    headless.eval-performance-mitigations-default =
      c: !(builtins.elem "mitigations=off" c.boot.kernelParams);

    # headless-tweaks: marchyo.performance.disableMitigations = true.
    headless-tweaks.eval-performance-mitigations-on-request =
      c: builtins.elem "mitigations=off" c.boot.kernelParams;

    # All toggles, including the aggressive compute opt-in (headless-tweaks-4).
    headless-tweaks-4.eval-performance-tuning-all =
      c: c.marchyo.performance.tuning.hugePages.enable && c.marchyo.performance.tuning.compute.enable;

    # Everything below is opt-in: the defaults leave the system untouched.
    headless.eval-performance-opt-in-defaults =
      c:
      let
        sysctl = c.boot.kernel.sysctl;
      in
      c.services.earlyoom.extraArgs == [ ]
      && c.services.earlyoom.freeSwapThreshold == 10
      && !(sysctl ? "kernel.panic_on_oops" || sysctl ? "kernel.panic" || sysctl ? "kernel.sysrq")
      && !(c.systemd.services ? mglru-min-ttl)
      && !c.services.below.enable
      && !(c.systemd.slices ? nix-build)
      && !(c.systemd.services.nix-daemon.serviceConfig ? Slice)
      && c.nix.daemonCPUSchedPolicy == "other"
      && c.nix.daemonIOSchedClass == "best-effort"
      && !(c.systemd.user.units ? "app-ghostty-surface-transient-.scope")
      && !(c.services.journald.settings.Journal ? SystemMaxUse)
      && !(c.services.journald.settings.Journal ? MaxRetentionSec);

    # headless-tweaks-2: oom steering. One anchored regex per flag, no --avoid.
    headless-tweaks-2.eval-performance-oom-args =
      c:
      [
        "--prefer"
        "^(llama-server)$"
        "--ignore"
        "^(Hyprland|pipewire)$"
        "--sort-by-rss"
      ] == c.services.earlyoom.extraArgs
      && c.services.earlyoom.freeSwapThreshold == 15
      && lib.hasInfix "--sort-by-rss" c.systemd.services.earlyoom.environment.EARLYOOM_ARGS;

    # headless-tweaks-2: terminal scope drop-in.
    headless-tweaks-2.eval-performance-terminal-limit =
      c:
      let
        unit = c.systemd.user.units."app-ghostty-surface-transient-.scope";
      in
      unit.overrideStrategy == "asDropin"
      && lib.hasInfix "MemoryHigh=8G" unit.text
      && lib.hasInfix "MemoryMax=12G" unit.text;

    # headless-tweaks-2: crash handling.
    headless-tweaks-2.eval-performance-crash =
      c:
      c.boot.kernel.sysctl."kernel.panic_on_oops" == 1
      && c.boot.kernel.sysctl."kernel.panic" == 10
      && c.boot.kernel.sysctl."kernel.sysrq" == 180;

    # headless-tweaks-2: MGLRU floor oneshot.
    headless-tweaks-2.eval-performance-mglru =
      c:
      let
        svc = c.systemd.services.mglru-min-ttl;
      in
      svc.unitConfig.ConditionPathExists == "/sys/kernel/mm/lru_gen/min_ttl_ms"
      && lib.hasInfix "echo 1000 > /sys/kernel/mm/lru_gen/min_ttl_ms" svc.script
      && svc.serviceConfig.Type == "oneshot"
      && svc.serviceConfig.CapabilityBoundingSet == "";

    # headless-tweaks-2: flight recorder with a bounded store.
    headless-tweaks-2.eval-performance-flight-recorder =
      c:
      c.services.below.enable
      && c.services.below.retention.size == 1073741824
      && c.services.below.retention.time == 604800;

    # headless-tweaks-4: nix build slice, daemon placement and idle classes.
    headless-tweaks-4.eval-nix-build-limits =
      c:
      let
        svc = c.systemd.services.nix-daemon.serviceConfig;
        slice = c.systemd.slices.nix-build.sliceConfig;
      in
      slice.MemoryHigh == "50%"
      && slice.MemoryMax == "65%"
      && svc.Slice == "nix-build.slice"
      && svc.OOMScoreAdjust == 500
      && svc.OOMPolicy == "continue"
      && c.nix.daemonCPUSchedPolicy == "idle"
      && c.nix.daemonIOSchedClass == "idle";

    # headless-tweaks-4: idle builds move kyber's rule to mq-deadline.
    headless-tweaks-4.eval-nix-build-limits-scheduler =
      c:
      let
        rules = c.services.udev.extraRules;
      in
      lib.hasInfix ''ATTR{queue/zoned}=="none", ATTR{queue/scheduler}="mq-deadline"'' rules
      && !(lib.hasInfix "kyber" rules);

    # headless-tweaks-2: zram swap is on, so memory tuning swaps early.
    headless-tweaks-2.eval-performance-memory-zram =
      c:
      c.zramSwap.enable
      && c.boot.kernel.sysctl."vm.swappiness" == 180
      && c.boot.kernel.sysctl."vm.watermark_scale_factor" == 125
      && c.boot.kernel.sysctl."vm.min_free_kbytes" == 524288;

    # headless-tweaks-4: without zram swap the memory tuning keeps RAM first.
    headless-tweaks-4.eval-performance-memory-no-zram =
      c:
      !c.zramSwap.enable
      && c.boot.kernel.sysctl."vm.swappiness" == 10
      && !(c.boot.kernel.sysctl ? "vm.watermark_scale_factor");

    # headless-tweaks-2: journald limits.
    headless-tweaks-2.eval-logging-journal =
      c:
      c.services.journald.settings.Journal.SystemMaxUse == "1G"
      && c.services.journald.settings.Journal.MaxRetentionSec == "1month";
  };

  refConfig = {
    headless-tweaks.marchyo.performance.disableMitigations = true;
    headless-tweaks-2.marchyo = {
      performance = {
        tuning.enable = true;
        oom = {
          preferProcesses = [ "llama-server" ];
          ignoreProcesses = [
            "Hyprland"
            "pipewire"
          ];
          freeSwapThreshold = 15;
        };
        terminalMemoryLimit = {
          high = "8G";
          max = "12G";
        };
        crash = {
          panicOnOops = true;
          sysrq = 180;
        };
        mglruMinTtlMs = 1000;
        flightRecorder.enable = true;
      };
      logging.journal = {
        maxUse = "1G";
        retention = "1month";
      };
    };
    headless-tweaks-4 = {
      marchyo.performance.tuning = {
        enable = true;
        hugePages.enable = true;
        compute.enable = true;
      };
      marchyo.nix.buildLimits = {
        enable = true;
        idlePriority = true;
      };
      zramSwap.enable = false;
    };
  };
}
