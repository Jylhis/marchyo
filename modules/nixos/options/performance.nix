{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.marchyo.performance.tuning;
  # A sub-toggle whose default follows the master `tuning.enable` switch.
  followsMaster =
    description:
    mkOption {
      inherit description;
      type = types.bool;
      default = cfg.enable;
      defaultText = lib.literalExpression "config.marchyo.performance.tuning.enable";
    };
in
{
  options.marchyo.performance = {
    disableMitigations = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Disable CPU vulnerability mitigations (Spectre, Meltdown, etc.) by
        passing `mitigations=off`, trading security for performance.

        Enable it only on a trusted single-user workstation (gaming,
        benchmarking, local development). Leave it off on any host that runs
        untrusted code or untrusted containers, is reachable by others, or
        builds code you did not write.
      '';
    };

    kyber.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use the kyber I/O scheduler on whole non-rotational disks (NVMe, SATA,
        MMC, virtio), except zoned disks. Kyber holds a read latency target,
        so interactive reads stay fast while large writes fill the disk queue.
        With `tuning.nvme.enable`, NVMe disks keep mq-deadline instead. With
        `marchyo.nix.buildLimits.idlePriority` the rule sets mq-deadline
        instead of kyber, because idle-class I/O yields only under an
        ioprio-aware scheduler.
      '';
    };

    oom = {
      preferProcesses = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "llama-server" ];
        description = ''
          Process-name regex fragments earlyoom kills first. They are joined
          into one anchored `--prefer '^(a|b)$'`. earlyoom matches the process
          `comm` name (`/proc/<pid>/comm`, at most 15 characters), not the unit
          or the command line, so a longer name never matches in full.

          Setting this or `ignoreProcesses` also adds `--sort-by-rss`: the
          victim is the largest process, which frees memory in one kill.
          Empty by default.
        '';
      };

      ignoreProcesses = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "Hyprland"
          "quickshell"
          "marchyo-shell"
          "pipewire"
          "wireplumber"
        ];
        description = ''
          Process-name regex fragments earlyoom never kills, joined into one
          anchored `--ignore '^(a|b)$'`. The `comm` rules of `preferProcesses`
          apply. The example lists the session processes of a marchyo desktop
          (compositor, shell and audio stack); the default is empty.
        '';
      };

      freeSwapThreshold = mkOption {
        type = types.nullOr (types.ints.between 1 100);
        default = null;
        example = 15;
        description = ''
          Free swap (percent) below which earlyoom starts killing. `null`
          keeps the `services.earlyoom.freeSwapThreshold` default (10). A
          higher value acts before a slow swap tier is nearly drained.
        '';
      };
    };

    terminalMemoryLimit = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            high = mkOption {
              type = types.str;
              example = "8G";
              description = "`MemoryHigh` (soft limit, throttles reclaim) of each terminal surface scope.";
            };
            max = mkOption {
              type = types.str;
              example = "12G";
              description = ''
                `MemoryMax` of each terminal surface scope. Past it the kernel
                kills the largest process of that terminal only.
              '';
            };
          };
        }
      );
      default = null;
      example = {
        high = "8G";
        max = "12G";
      };
      description = ''
        Memory bounds for each Ghostty surface (tab, split, window). Ghostty
        runs every surface in a transient user scope named
        `app-ghostty-surface-transient-<pid>.scope` when `linux-cgroup` is
        `single-instance` (its default; marchyo runs Ghostty single-instance)
        or `always`. A prefix drop-in on that name bounds all of them, so one
        terminal cannot starve the others. `null` sets no limit. Surfaces that
        are already open keep their old limits.
      '';
    };

    crash = {
      panicOnOops = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Reboot after a kernel oops instead of staying wedged: sets
          `kernel.panic_on_oops = 1` and `kernel.panic = 10` (reboot after 10
          seconds). With a persistent journal the oops trace survives.
        '';
      };

      sysrq = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 180;
        description = ''
          Bitmask for `kernel.sysrq`. `null` leaves the system default.
          For example 180 allows sync, remount read-only and reboot plus
          keyboard control (bits 4, 16, 32 and 128), without signal sending
          (bit 64) or debug dumps.
        '';
      };
    };

    mglruMinTtlMs = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      example = 1000;
      description = ''
        MGLRU anti-thrash floor in milliseconds, written to
        `/sys/kernel/mm/lru_gen/min_ttl_ms` at boot by a oneshot unit. The
        kernel keeps the working set of that age in memory and lets the OOM
        killer act instead of thrashing. `null` leaves the kernel default (0).
        The unit does nothing on a kernel without MGLRU.
      '';
    };

    flightRecorder.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Record CPU, memory and pressure history with `below` (replay the
        minutes before a freeze with `below replay`). The store is bounded to
        1 GiB and 7 days (`services.below.retention`, both `lib.mkDefault`).
      '';
    };

    tuning = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable kernel/sysctl/IO performance tuning for throughput-oriented
          workloads.

          Turning this on enables the broadly-safe sub-toggles (network, nvme,
          memory, hugePages) by default. The aggressive compute toggle stays
          off and must be opted into explicitly.
        '';
      };

      network.enable = followsMaster ''
        Network stack tuning: TCP Fast Open, window scaling, larger socket
        buffers and backlogs. BBR, fq and MTU probing are on without it.
        Broadly safe and beneficial. Defaults to the value of tuning.enable.
      '';

      nvme.enable = followsMaster ''
        NVMe SSD I/O tuning via udev rules: mq-deadline scheduler (in place of
        kyber, because idle-class I/O only yields under an ioprio-aware
        scheduler), larger read-ahead and max request size. Safe for NVMe
        SSDs. Defaults to tuning.enable.
      '';

      memory = {
        enable = followsMaster ''
          Virtual-memory tuning: swappiness 10 (180 while `zramSwap` is on),
          keep filesystem metadata cached, and cap dirty-page writeback by absolute byte thresholds (see
          dirtyBytes/dirtyBackgroundBytes). Broadly safe. Defaults to tuning.enable.
        '';

        dirtyBytes = mkOption {
          type = types.ints.positive;
          default = 268435456; # 256 MiB
          description = ''
            vm.dirty_bytes — absolute dirty-page threshold that forces synchronous
            writeback. Absolute byte limits avoid the large dirty-page buildup and
            latency spikes that ratio-based defaults cause on high-RAM machines.
          '';
        };

        dirtyBackgroundBytes = mkOption {
          type = types.ints.positive;
          default = 67108864; # 64 MiB
          description = ''
            vm.dirty_background_bytes — dirty-page threshold at which the kernel
            starts background writeback.
          '';
        };
      };

      hugePages.enable = followsMaster ''
        Transparent huge pages on request (transparent_hugepage=madvise): only
        allocations that madvise(MADV_HUGEPAGE) get 2 MiB pages, so RSS does not
        bloat as with `always`. Defaults to tuning.enable.
      '';

      compute.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Relax resource limits for trusted single-user compute/CUDA hosts: PAM
          loginLimits granting @users unlimited memlock (GPU memory pinning), real-time
          priority, 1M open files and unlimited processes, plus kernel.sched_rt_runtime_us=-1.

          SECURITY/STABILITY SENSITIVE — only enable on trusted single-user machines
          where you control every process. Off by default.
        '';
      };
    };
  };
}
