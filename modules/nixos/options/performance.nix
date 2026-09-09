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
        Disable CPU vulnerability mitigations (Spectre, Meltdown, etc.) by
        passing `mitigations=off`, trading security for performance.

        WARNING: this defaults to `true`, so mitigations are OFF unless you set
        it to `false`. That default suits the trusted single-user workstations
        marchyo targets (gaming, benchmarking, local development). Set it to
        `false` on any host that runs untrusted code or untrusted containers —
        including anything reachable by others, or a CI/build machine executing
        code you did not write.

        A host that enables a container runtime while this is on gets a build
        warning; see `modules/nixos/performance.nix`.
      '';
    };

    kernel = mkOption {
      type = types.enum [
        "default"
        "latest"
        "zen"
        "xanmod"
        "lts"
      ];
      default = "default";
      example = "zen";
      description = ''
        Kernel variant to boot.

        - `"default"` — leave `boot.kernelPackages` unmanaged (the nixpkgs
          default kernel, or whatever the host sets).
        - `"latest"` — newest mainline kernel (`linuxPackages_latest`); best
          hardware support, shortest support window.
        - `"zen"` — ZEN kernel (`linuxPackages_zen`); tuned for desktop
          interactivity and low latency.
        - `"xanmod"` — XanMod kernel (`linuxPackages_xanmod_latest`); mainline
          with performance-oriented patches (gaming/workstation).
        - `"lts"` — long-term-support kernel (`linuxPackages`); most
          conservative choice for servers and stable hosts.

        The mapping is applied with `lib.mkDefault`, so a host can still set
        `boot.kernelPackages` directly to override it.
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
