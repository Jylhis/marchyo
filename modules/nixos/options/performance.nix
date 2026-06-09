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
      default = true;
      description = ''
        Disable CPU vulnerability mitigations (Spectre, Meltdown, etc.) for maximum performance.
        WARNING: This reduces security. Only enable on trusted single-user workstations
        where maximum performance is required (e.g., gaming, benchmarking).
        Do NOT enable if running untrusted code or containers.
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
          memory) by default. The aggressive toggles (hugePages, compute) stay
          off and must be opted into explicitly.
        '';
      };

      network.enable = followsMaster ''
        Network stack tuning: BBR congestion control (loads the tcp_bbr module),
        TCP Fast Open, MTU probing, larger socket buffers and backlogs.
        Broadly safe and beneficial. Defaults to the value of tuning.enable.
      '';

      nvme.enable = followsMaster ''
        NVMe SSD I/O tuning via udev rules: no-op scheduler, larger read-ahead
        and max request size. Safe for NVMe SSDs. Defaults to tuning.enable.
      '';

      memory = {
        enable = followsMaster ''
          Virtual-memory tuning: lower swappiness, keep filesystem metadata
          cached, and cap dirty-page writeback by absolute byte thresholds (see
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

      hugePages.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable 2 MiB transparent huge pages always (transparent_hugepage=always,
          hugepagesz=2M). Improves TLB performance for large allocations but can
          hurt latency-sensitive and interactive desktop workloads. Off by default.
        '';
      };

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
