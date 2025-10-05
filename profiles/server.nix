# Server profile - minimal headless server configuration
#
# Provides a secure, hardened server environment with SSH access, monitoring tools,
# and automatic updates. Desktop features are explicitly disabled for reduced attack
# surface and resource usage. Ideal for VPS, home servers, and infrastructure hosts.

{ lib, pkgs, ... }:

{
  imports = [
    ./base.nix
  ];

  # ============================================================================
  # DESKTOP FEATURES DISABLED
  # Servers don't need GUI applications or desktop environments
  # ============================================================================

  marchyo.desktop.enable = false;
  marchyo.office.enable = false;
  marchyo.media.enable = false;
  # Development tools disabled by default but can be overridden per-host if needed
  marchyo.development.enable = lib.mkDefault false;

  # ============================================================================
  # SSH SERVER CONFIGURATION
  # Secure remote access with key-based authentication only
  # ============================================================================

  services.openssh = {
    enable = true;
    settings = {
      # Prevent root login over SSH
      PermitRootLogin = "no";
      # Disable password authentication - require SSH keys only
      PasswordAuthentication = false;
      # Disable keyboard-interactive authentication
      KbdInteractiveAuthentication = false;
      # Use stronger key exchange algorithms
      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group-exchange-sha256"
      ];
    };
    # Listen on all interfaces
    openFirewall = true;
  };

  # ============================================================================
  # FIREWALL CONFIGURATION
  # Only allow SSH by default - add other ports per-host as needed
  # ============================================================================

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH only
    allowedUDPPorts = [ ]; # No UDP ports by default
    # Log dropped packets for security monitoring
    logRefusedConnections = lib.mkDefault true;
  };

  # ============================================================================
  # AUTOMATIC UPDATES
  # Keep system secure with automatic updates
  # ============================================================================

  system.autoUpgrade = {
    enable = lib.mkDefault true;
    allowReboot = lib.mkDefault false; # Don't auto-reboot, let admin decide
    dates = "04:00"; # Run at 4 AM
    randomizedDelaySec = "30min"; # Randomize to avoid all servers updating at once
  };

  # ============================================================================
  # FAIL2BAN - SSH BRUTE FORCE PROTECTION
  # Automatically ban IPs that show malicious signs
  # ============================================================================

  services.fail2ban = {
    enable = true;
    maxretry = 5; # Ban after 5 failed attempts
    bantime = "10m"; # Ban for 10 minutes initially
    bantime-increment = {
      enable = true; # Increase ban time for repeat offenders
      formula = "ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * banFactor";
      maxtime = "48h"; # Maximum ban time
      overalljails = true; # Track across all jails
    };
    # SSH jail is enabled by default
  };

  # ============================================================================
  # JOURNALD CONFIGURATION
  # Persistent logs with reasonable size limits for troubleshooting
  # ============================================================================

  services.journald.extraConfig = ''
    # Store logs persistently on disk
    Storage=persistent
    # Compress logs to save space
    Compress=yes
    # Keep logs for up to 1 month
    MaxRetentionSec=1month
    # Limit total log size to 500MB
    SystemMaxUse=500M
    # Keep at least 100MB free on disk
    SystemKeepFree=100M
    # Individual log file size limit
    SystemMaxFileSize=50M
  '';

  # ============================================================================
  # DISABLE UNNECESSARY SERVICES
  # Reduce attack surface and resource usage
  # Use mkForce to override any module defaults
  # ============================================================================

  # No Bluetooth on servers
  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable = lib.mkForce false;

  # No printing services
  services.printing.enable = lib.mkForce false;

  # No CUPS (printing system)
  services.avahi.enable = lib.mkForce false;

  # No GUI display manager
  services.xserver.enable = lib.mkForce false;

  # No desktop sound system
  sound.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;

  # No geolocation services
  services.geoclue2.enable = lib.mkForce false;

  # No thumbnail generation
  services.tumbler.enable = lib.mkForce false;

  # No GNOME keyring
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # ============================================================================
  # SERVER MONITORING AND DEBUGGING PACKAGES
  # Essential tools for system administration and troubleshooting
  # ============================================================================

  environment.systemPackages = with pkgs; [
    # Process monitoring
    htop # Interactive process viewer
    iotop # I/O monitoring

    # Network diagnostics
    lsof # List open files and network connections
    tcpdump # Network packet analyzer

    # System debugging
    strace # System call tracer
    ltrace # Library call tracer

    # Disk usage
    ncdu # NCurses disk usage analyzer

    # General utilities
    tmux # Terminal multiplexer for persistent sessions
    vim # Text editor
  ];

  # ============================================================================
  # PERFORMANCE TUNING
  # Optimize for server workloads
  # ============================================================================

  # Disable unnecessary desktop-oriented features
  services.locate.enable = lib.mkForce false; # File indexing not needed on servers
  services.upower.enable = lib.mkForce false; # Power management for laptops

  # Enable kernel parameters for better server performance
  boot.kernel.sysctl = {
    # Increase the number of file descriptors
    "fs.file-max" = lib.mkDefault 2097152;
    # TCP tuning for better network performance
    "net.core.rmem_max" = lib.mkDefault 134217728;
    "net.core.wmem_max" = lib.mkDefault 134217728;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 67108864";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 67108864";
  };

  # ============================================================================
  # SECURITY HARDENING
  # Additional security measures for server environments
  # ============================================================================

  # Require password for sudo (more secure for servers)
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # Disable sudo timeout (require password every time)
  security.sudo.extraConfig = lib.mkDefault ''
    Defaults timestamp_timeout=0
  '';
}
