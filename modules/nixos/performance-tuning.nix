# Opt-in kernel/sysctl/IO performance tuning for throughput-oriented workloads.
#
# Gated behind marchyo.performance.tuning.* and split by risk profile:
#   - network / nvme / memory : broadly safe, on when tuning.enable is set
#   - hugePages / compute     : aggressive, off by default
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
  cfg = config.marchyo.performance.tuning;
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.network.enable {
        # BBR needs its module loaded before the sysctl takes effect.
        boot.kernelModules = [ "tcp_bbr" ];
        boot.kernel.sysctl = {
          "net.core.rmem_max" = lib.mkDefault 20971520; # 20 MiB max receive buffer
          "net.core.wmem_max" = lib.mkDefault 20971520; # 20 MiB max send buffer
          "net.core.netdev_max_backlog" = lib.mkDefault 5000;
          "net.core.somaxconn" = lib.mkDefault 4096;
          "net.ipv4.tcp_fastopen" = lib.mkDefault 3; # client + server
          "net.ipv4.tcp_mtu_probing" = lib.mkDefault 1;
          "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
          "net.ipv4.tcp_window_scaling" = lib.mkDefault 1;
          # Auto-tuning buffers, 32 MiB max for large transfers.
          "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 33554432";
          "net.ipv4.tcp_wmem" = lib.mkDefault "4096 87380 33554432";
        };
      })

      (lib.mkIf cfg.nvme.enable {
        # Target only NVMe disk block devices (not controllers or partitions).
        services.udev.extraRules = ''
          ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="none"
          ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/read_ahead_kb}="1024"
          ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/max_sectors_kb}="1024"
        '';
      })

      (lib.mkIf cfg.memory.enable {
        boot.kernel.sysctl = {
          "vm.swappiness" = lib.mkDefault 10; # Prefer RAM over swap
          "vm.vfs_cache_pressure" = lib.mkDefault 50; # Keep filesystem metadata cached
          "vm.min_free_kbytes" = lib.mkDefault 524288; # Reserve 512 MiB for the kernel
          "vm.dirty_bytes" = lib.mkDefault cfg.memory.dirtyBytes;
          "vm.dirty_background_bytes" = lib.mkDefault cfg.memory.dirtyBackgroundBytes;
        };
      })

      (lib.mkIf cfg.hugePages.enable {
        boot.kernelParams = [
          "transparent_hugepage=always" # Better TLB performance for large allocations
          "hugepagesz=2M"
        ];
      })

      (lib.mkIf cfg.compute.enable {
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
    ]
  );
}
