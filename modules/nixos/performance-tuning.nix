# Kernel/sysctl/IO performance settings.
#
# Always on (overridable): BBR + fq, MTU probing, and kyber on non-rotational
# disks. The rest is opt-in behind marchyo.performance.tuning.*, split by risk:
#   - network / nvme / memory / hugePages : broadly safe, on when tuning.enable is set
#   - compute                             : aggressive, off by default
#
# Deliberately omitted (vs. an older compute-host tuning set): the CFS scheduler
# sysctls (kernel.sched_min_granularity_ns, sched_latency_ns,
# sched_wakeup_granularity_ns, sched_migration_cost_ns, sched_cfs_bandwidth_slice_us,
# sched_autogroup_enabled). These were removed when the kernel switched
# CFS -> EEVDF (6.6+); setting them on a current kernel only produces
# systemd-sysctl warnings. kernel.sched_rt_runtime_us still exists and lives
# under the `compute` toggle.
{ config, lib, ... }:
let
  perf = config.marchyo.performance;
  cfg = perf.tuning;
  nvmeTuned = cfg.enable && cfg.nvme.enable;
  # Partitions have no scheduler of their own, and loop, zram and dm devices
  # are not matched. Zoned disks need mq-deadline. With NVMe tuning on, NVMe
  # disks keep its mq-deadline rule so the two rules never race.
  kyberKernels = lib.concatStringsSep "|" (
    lib.optional (!nvmeTuned) "nvme*"
    ++ [
      "sd*"
      "mmcblk*"
      "vd*"
    ]
  );
in
{
  config = lib.mkMerge [
    {
      # BBR needs its module loaded before the sysctl takes effect; fq is the
      # qdisc BBR paces through.
      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = lib.mkDefault "fq";
        "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
        "net.ipv4.tcp_mtu_probing" = lib.mkDefault 1;
      };
    }

    (lib.mkIf perf.kyber.enable {
      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="${kyberKernels}", ATTR{queue/rotational}=="0", ATTR{queue/zoned}=="none", ATTR{queue/scheduler}="kyber"
      '';
    })

    (lib.mkIf (cfg.enable && cfg.network.enable) {
      boot.kernel.sysctl = {
        "net.core.rmem_max" = lib.mkDefault 20971520; # 20 MiB
        "net.core.wmem_max" = lib.mkDefault 20971520; # 20 MiB
        "net.core.netdev_max_backlog" = lib.mkDefault 5000;
        "net.core.somaxconn" = lib.mkDefault 4096;
        "net.ipv4.tcp_fastopen" = lib.mkDefault 3; # client + server
        "net.ipv4.tcp_window_scaling" = lib.mkDefault 1;
        # Auto-tuning buffers, 32 MiB max for large transfers.
        "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 33554432";
        "net.ipv4.tcp_wmem" = lib.mkDefault "4096 87380 33554432";
      };
    })

    (lib.mkIf (cfg.enable && cfg.nvme.enable) {
      # Target only NVMe disk block devices (not controllers or partitions).
      # mq-deadline, not none: idle-class nix builds and bees only yield disk
      # IO under an ioprio-aware scheduler.
      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="mq-deadline"
        ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/read_ahead_kb}="1024"
        ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/max_sectors_kb}="1024"
      '';
    })

    (lib.mkIf (cfg.enable && cfg.memory.enable) {
      boot.kernel.sysctl = {
        "vm.swappiness" = lib.mkDefault 10; # Prefer RAM over swap
        "vm.vfs_cache_pressure" = lib.mkDefault 50; # Keep filesystem metadata cached
        "vm.min_free_kbytes" = lib.mkDefault 524288; # Reserve 512 MiB for the kernel
        "vm.dirty_bytes" = lib.mkDefault cfg.memory.dirtyBytes;
        "vm.dirty_background_bytes" = lib.mkDefault cfg.memory.dirtyBackgroundBytes;
      };
    })

    (lib.mkIf (cfg.enable && cfg.hugePages.enable) {
      boot.kernelParams = [
        # Huge pages for allocations that ask via madvise; `always` bloats RSS
        # and ClickHouse warns about it.
        "transparent_hugepage=madvise"
      ];
    })

    (lib.mkIf (cfg.enable && cfg.compute.enable) {
      boot.kernel.sysctl = {
        "kernel.sched_rt_runtime_us" = lib.mkDefault (-1); # Allow RT tasks 100% CPU time
      };
      security.pam.loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = "99"; # Allow full real-time priority
        }
        {
          domain = "@users";
          item = "nice";
          type = "-";
          value = "-20"; # Allow highest nice priority
        }
        {
          domain = "@users";
          item = "memlock";
          type = "-";
          value = "unlimited"; # Critical for GPU memory pinning (CUDA)
        }
        {
          domain = "@users";
          item = "nofile";
          type = "-";
          value = "1048576"; # 1M open file descriptors
        }
        {
          domain = "@users";
          item = "nproc";
          type = "-";
          value = "unlimited";
        }
      ];
    })
  ];
}
