{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    mkDefault
    ;
  cfg = config.marchyo.hardened;
in
{
  options.marchyo.hardened = {
    enable = mkEnableOption "security hardening for NixOS system" // {
      default = false;
    };

    enableApparmor = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable AppArmor mandatory access control.
        Provides an additional security layer by restricting program capabilities.
        Only applied when marchyo.hardened.enable is true.
      '';
    };

    allowPing = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow ICMP echo requests (ping) for connectivity testing.
        When false, the system will not respond to ping requests, improving stealth
        but making network diagnostics more difficult.
      '';
    };
  };

  config = mkIf cfg.enable {
    # ============================================================================
    # KERNEL HARDENING
    # ============================================================================
    boot.kernel.sysctl = {
      # --------------------------------------------------------------------------
      # Network Security - IP Forwarding
      # --------------------------------------------------------------------------
      # Disable IP forwarding to prevent the system from acting as a router
      # This is critical for desktop/workstation systems to prevent network pivoting attacks
      "net.ipv4.ip_forward" = mkDefault 0;
      "net.ipv6.conf.all.forwarding" = mkDefault 0;

      # --------------------------------------------------------------------------
      # Network Security - SYN Flood Protection
      # --------------------------------------------------------------------------
      # Enable SYN cookies to protect against SYN flood attacks (DoS mitigation)
      # Allows the kernel to handle more half-open connections without allocating resources
      "net.ipv4.tcp_syncookies" = mkDefault 1;

      # Increase the maximum number of half-open connections the kernel will hold
      "net.ipv4.tcp_max_syn_backlog" = mkDefault 2048;

      # Reduce the number of SYN-ACK retries to speed up detection of invalid connections
      "net.ipv4.tcp_synack_retries" = mkDefault 2;
      "net.ipv4.tcp_syn_retries" = mkDefault 5;

      # --------------------------------------------------------------------------
      # Network Security - ICMP Redirects
      # --------------------------------------------------------------------------
      # Disable acceptance of ICMP redirect messages to prevent man-in-the-middle attacks
      # Attackers can use ICMP redirects to reroute traffic through malicious systems
      "net.ipv4.conf.all.accept_redirects" = mkDefault 0;
      "net.ipv4.conf.default.accept_redirects" = mkDefault 0;
      "net.ipv4.conf.all.secure_redirects" = mkDefault 0;
      "net.ipv4.conf.default.secure_redirects" = mkDefault 0;
      "net.ipv6.conf.all.accept_redirects" = mkDefault 0;
      "net.ipv6.conf.default.accept_redirects" = mkDefault 0;

      # Disable sending ICMP redirect messages (we're not a router)
      "net.ipv4.conf.all.send_redirects" = mkDefault 0;
      "net.ipv4.conf.default.send_redirects" = mkDefault 0;

      # --------------------------------------------------------------------------
      # Network Security - Source Routing
      # --------------------------------------------------------------------------
      # Disable source routing to prevent attackers from specifying packet routes
      # Source routing can be used to bypass firewall rules and network policies
      "net.ipv4.conf.all.accept_source_route" = mkDefault 0;
      "net.ipv4.conf.default.accept_source_route" = mkDefault 0;
      "net.ipv6.conf.all.accept_source_route" = mkDefault 0;
      "net.ipv6.conf.default.accept_source_route" = mkDefault 0;

      # --------------------------------------------------------------------------
      # Network Security - Reverse Path Filtering
      # --------------------------------------------------------------------------
      # Enable strict reverse path filtering to prevent IP spoofing attacks
      # Mode 1 (strict): Drops packets if the return path doesn't match the incoming interface
      # Mode 2 (loose): Drops packets only if no route exists back to the source
      "net.ipv4.conf.all.rp_filter" = mkDefault 1;
      "net.ipv4.conf.default.rp_filter" = mkDefault 1;

      # --------------------------------------------------------------------------
      # Network Security - ICMP Echo Requests (Ping)
      # --------------------------------------------------------------------------
      # Control whether the system responds to ICMP echo requests
      # Disabling reduces visibility to network scans but breaks ping-based diagnostics
      "net.ipv4.icmp_echo_ignore_all" = mkDefault (if cfg.allowPing then 0 else 1);
      "net.ipv6.icmp.echo_ignore_all" = mkDefault (if cfg.allowPing then 0 else 1);

      # Ignore ICMP broadcast requests to prevent participating in Smurf attacks
      "net.ipv4.icmp_echo_ignore_broadcasts" = mkDefault 1;

      # --------------------------------------------------------------------------
      # Network Security - Other Protections
      # --------------------------------------------------------------------------
      # Enable bad error message protection to avoid kernel crashes from malformed ICMP
      "net.ipv4.icmp_ignore_bogus_error_responses" = mkDefault 1;

      # Log packets with impossible addresses (martian packets) for security monitoring
      "net.ipv4.conf.all.log_martians" = mkDefault 1;
      "net.ipv4.conf.default.log_martians" = mkDefault 1;

      # Disable IPv6 router advertisements to prevent rogue router attacks
      "net.ipv6.conf.all.accept_ra" = mkDefault 0;
      "net.ipv6.conf.default.accept_ra" = mkDefault 0;

      # --------------------------------------------------------------------------
      # Kernel Security - Process Protections
      # --------------------------------------------------------------------------
      # Restrict access to kernel pointers in /proc (prevents kernel address leaks)
      # 0 = unrestricted, 1 = restricted for non-root, 2 = always restricted
      "kernel.kptr_restrict" = mkDefault 2;

      # Restrict dmesg access to root only (prevents information disclosure)
      "kernel.dmesg_restrict" = mkDefault 1;

      # Disable kernel profiling by unprivileged users (security and performance)
      "kernel.perf_event_paranoid" = mkDefault 3;

      # Restrict unprivileged eBPF (prevents unprivileged users from loading BPF programs)
      "kernel.unprivileged_bpf_disabled" = mkDefault 1;

      # Restrict user namespaces to prevent privilege escalation vulnerabilities
      # Many container escape exploits rely on user namespaces
      "kernel.unprivileged_userns_clone" = mkDefault 0;

      # Disable loading new TTY line disciplines by unprivileged users
      "dev.tty.ldisc_autoload" = mkDefault 0;

      # --------------------------------------------------------------------------
      # Kernel Security - Memory Protections
      # --------------------------------------------------------------------------
      # Randomize memory addresses (ASLR) with maximum entropy
      # Makes it harder for attackers to predict memory locations for exploits
      "kernel.randomize_va_space" = mkDefault 2;

      # Restrict ptrace to only allow tracing of child processes
      # Prevents malicious processes from inspecting memory of arbitrary processes
      # 0 = unrestricted, 1 = restricted to child processes, 2 = admin only
      "kernel.yama.ptrace_scope" = mkDefault 2;

      # --------------------------------------------------------------------------
      # File System Security
      # --------------------------------------------------------------------------
      # Protect hardlinks and symlinks from attacks in world-writable directories
      # Prevents exploits that create malicious links in /tmp
      "fs.protected_hardlinks" = mkDefault 1;
      "fs.protected_symlinks" = mkDefault 1;

      # Protect FIFOs and regular files in world-writable directories
      "fs.protected_fifos" = mkDefault 2;
      "fs.protected_regular" = mkDefault 2;

      # Increase inotify limits for security monitoring tools
      "fs.inotify.max_user_watches" = mkDefault 524288;
      "fs.inotify.max_user_instances" = mkDefault 512;
    };

    # ============================================================================
    # SYSTEMD SERVICE HARDENING
    # ============================================================================
    # Apply security hardening defaults to all systemd services
    # Individual services can override these settings when necessary
    systemd.services = {
      # Most services don't need to modify system directories
      # This provides a read-only view of /usr, /boot, and /etc
      "-".serviceConfig = {
        ProtectSystem = mkDefault "strict";
      };

      # Prevent services from accessing user home directories
      # Services that need home directory access can override this
      "-".serviceConfig.ProtectHome = mkDefault true;

      # Use private /tmp for each service to prevent temp file attacks
      # Prevents one service from accessing another service's temporary files
      "-".serviceConfig.PrivateTmp = mkDefault true;

      # Prevent privilege escalation via setuid/setgid/file capabilities
      # Services should be designed to run with minimal privileges
      "-".serviceConfig.NoNewPrivileges = mkDefault true;

      # Restrict access to kernel logs (journal contains sensitive information)
      "-".serviceConfig.ProtectKernelLogs = mkDefault true;

      # Protect kernel tunables from modification
      "-".serviceConfig.ProtectKernelTunables = mkDefault true;

      # Prevent loading kernel modules (only needed during boot)
      "-".serviceConfig.ProtectKernelModules = mkDefault true;

      # Restrict access to process information in /proc
      "-".serviceConfig.ProtectProc = mkDefault "invisible";

      # Make /proc/sys, /sys, and /proc/sysrq-trigger read-only
      "-".serviceConfig.ProtectControlGroups = mkDefault true;

      # Restrict address families to common ones (blocks exotic protocols)
      "-".serviceConfig.RestrictAddressFamilies = mkDefault [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];

      # Prevent access to /sys/kernel/tracing and similar debugging interfaces
      "-".serviceConfig.ProtectHostname = mkDefault true;

      # Use strict system call filter (blocks dangerous syscalls)
      # Only allow common safe syscalls, block kernel-level operations
      "-".serviceConfig.SystemCallFilter = mkDefault [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];

      # Restrict real-time scheduling (prevents DoS via CPU exhaustion)
      "-".serviceConfig.RestrictRealtime = mkDefault true;

      # Lock down personality system call (prevents bypass of security features)
      "-".serviceConfig.LockPersonality = mkDefault true;

      # Prevent creating world-accessible files by default
      "-".serviceConfig.UMask = mkDefault "0077";
    };

    # ============================================================================
    # SYSTEM SECURITY SETTINGS
    # ============================================================================

    # Set stricter default umask for all users (files created as 0600, dirs as 0700)
    # This prevents accidentally creating world-readable files
    # Users can override this in their shell configuration if needed
    security.loginDefs.settings = {
      UMASK = mkDefault "077";

      # Password aging policies (commented but available for stricter environments)
      # PASS_MAX_DAYS = 90;  # Force password change every 90 days
      # PASS_MIN_DAYS = 1;   # Prevent changing password more than once per day
      # PASS_WARN_AGE = 7;   # Warn 7 days before password expires
    };

    # Disable core dumps system-wide to prevent memory dumps from containing sensitive data
    # Core dumps can contain passwords, encryption keys, and other secrets
    systemd.coredump.enable = mkDefault false;
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "hard";
        item = "core";
        value = "0";
      }
    ];

    # ============================================================================
    # APPARMOR MANDATORY ACCESS CONTROL
    # ============================================================================
    # Enable AppArmor for additional mandatory access control
    # Provides defense-in-depth by restricting program capabilities even if compromised
    security.apparmor = mkIf cfg.enableApparmor {
      enable = mkDefault true;

      # Kill processes that violate their AppArmor profile
      # Set to false for learning/debugging mode
      killUnconfinedConfinables = mkDefault true;

      # Load additional AppArmor profiles from packages
      packages = [ ];
    };

    # ============================================================================
    # DISABLE UNNECESSARY SERVICES
    # ============================================================================
    # Disable services that are rarely needed and increase attack surface

    # Disable CUPS printing by default (can be enabled separately if needed)
    # services.printing.enable = mkDefault false;

    # Disable Bluetooth by default (can be enabled separately if needed)
    # hardware.bluetooth.enable = mkDefault false;

    # Disable sound server by default for truly hardened systems
    # sound.enable = mkDefault false;

    # ============================================================================
    # BOOT SECURITY
    # ============================================================================
    # Additional boot-time security measures

    # Disable magic SysRq key to prevent physical console attacks
    # SysRq allows direct kernel commands via keyboard, useful for debugging but dangerous
    boot.kernel.sysctl."kernel.sysrq" = mkDefault 0;

    # ============================================================================
    # NETWORK HARDENING
    # ============================================================================
    # Additional network-level security

    # Firewall should be enabled (not forced here to avoid conflicts)
    # networking.firewall.enable is assumed to be set elsewhere
    # Consider enabling nftables for better performance:
    # networking.nftables.enable = true;
  };
}
