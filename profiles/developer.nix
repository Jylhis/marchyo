# Developer profile - development-focused workstation
#
# Extends the desktop profile with development tools, containerization,
# and virtualization support. Optimized for software development workflows.

{ lib, pkgs, ... }:

{
  imports = [
    ./desktop.nix
  ];

  # Enable development feature flag
  marchyo.development.enable = true;

  # Development-friendly shell
  programs = {
    # Git with advanced configuration
    git = {
      enable = true;
      lfs.enable = true;
    };

    # Development shells
    fish.enable = true;
    bash.enableCompletion = true;

    # Direnv for project environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  # Virtualization for testing and development
  virtualisation = {
    # Docker
    docker = {
      enable = true;
      enableOnBoot = lib.mkDefault false; # Start manually to save resources
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # Podman as Docker alternative
    podman = {
      enable = lib.mkDefault false;
      dockerCompat = false; # Don't conflict with Docker
    };

    # libvirt for VMs
    libvirtd = {
      enable = lib.mkDefault true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };
  };

  # Development tools in system packages
  environment.systemPackages = with pkgs; [
    # Version control
    git
    gh # GitHub CLI

    # Build tools
    gnumake
    cmake
    gcc
    pkg-config

    # Container tools
    docker-compose
    lazydocker

    # Virtual machines
    virt-manager
    virt-viewer

    # Database clients
    sqlite

    # Network debugging
    curl
    wget
    netcat
    nmap
    tcpdump

    # Development utilities
    jq
    yq
    tree
    ripgrep
    fd
    bat
    eza
  ];

  # Enable virtualization features
  boot.kernelModules = [
    "kvm-intel"
    "kvm-amd"
  ];

  # Performance tuning for development
  boot.kernel.sysctl = {
    # Increase file watchers for development tools
    "fs.inotify.max_user_watches" = lib.mkDefault 524288;
    "fs.inotify.max_user_instances" = lib.mkDefault 512;

    # Increase file descriptors
    "fs.file-max" = lib.mkDefault 2097152;
  };

  # Networking for development
  networking = {
    # Firewall exceptions for development servers
    firewall = {
      allowedTCPPortRanges = [
        {
          from = 3000;
          to = 3999;
        } # Common dev server ports
        {
          from = 8000;
          to = 8999;
        } # Alternative dev server ports
      ];
    };
  };

  # Documentation for development
  documentation.dev.enable = true;
}
