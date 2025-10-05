# Marchyo Graphical Installation ISO Configuration
#
# This configuration builds a graphical installation ISO image for Marchyo.
# It provides a full desktop environment with Calamares installer and helpful
# tools for both GUI and CLI-based installation workflows.
#
# Build with: nix build .#nixosConfigurations.iso-graphical.config.system.build.isoImage

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares.nix>
  ];

  # System Identification
  networking.hostName = "marchyo-installer-graphical";
  system.stateVersion = "24.11";

  # Enable Flakes and Modern Nix Commands
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Marchyo Branding
  isoImage = {
    isoName = lib.mkForce "marchyo-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}.iso";
    volumeID = lib.mkForce "MARCHYO_INSTALL";

    # Custom Plymouth splash screen (if available)
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # Enhanced Console for Better Readability
  console = {
    font = "ter-v32n";
    packages = with pkgs; [ terminus_font ];
    earlySetup = true;
  };

  # Desktop Environment Customization
  services.xserver = {
    enable = true;

    # Use a lightweight desktop environment
    desktopManager.plasma5.enable = true;

    # Auto-login for convenience
    displayManager.autoLogin = {
      enable = true;
      user = "nixos";
    };
  };

  # Custom wallpaper with Marchyo branding
  environment.etc."wallpaper.png".source =
    pkgs.runCommand "marchyo-wallpaper"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        # Create a gradient wallpaper with Marchyo colors
        convert -size 1920x1080 \
          gradient:'#1e3a8a'-'#3b82f6' \
          -gravity center \
          -pointsize 96 \
          -fill white \
          -annotate +0+0 'Marchyo' \
          -pointsize 32 \
          -annotate +0+120 'NixOS Installation' \
          $out
      '';

  # Set the custom wallpaper for Plasma
  environment.etc."xdg/plasma-workspace/env/set-wallpaper.sh" = {
    text = ''
      #!/bin/sh
      cp /etc/wallpaper.png ~/.config/wallpaper.png
    '';
    mode = "0755";
  };

  # SSH for Remote Installation Assistance
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Installation Tools - Enhanced Package Set
  environment.systemPackages = with pkgs; [
    # Core Installation Tools
    calamares-nixos
    calamares-nixos-extensions

    # Documentation Browser
    firefox

    # GUI Partitioning
    gparted
    gnome.gnome-disk-utility

    # Text Editors
    vim
    nano
    kate
    gedit
    # vscode  # Commented out due to large size (~300MB)

    # Terminal Emulators
    kitty
    alacritty

    # File Managers
    pcmanfm
    dolphin

    # System Information
    neofetch
    fastfetch
    htop
    btop

    # Disk and Filesystem Tools
    parted
    gptfdisk
    ntfs3g
    exfatprogs
    dosfstools
    e2fsprogs
    btrfs-progs
    xfsprogs
    f2fs-tools

    # Network Tools
    networkmanagerapplet
    wget
    curl
    rsync

    # Compression Tools
    unzip
    p7zip

    # Git for fetching configurations
    git

    # Hardware Detection
    pciutils
    usbutils
    lshw

    # Minimal from minimal ISO
    nixos-install-tools
  ];

  # Desktop File for Quick Installation Guide
  environment.etc."xdg/autostart/marchyo-welcome.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Install Marchyo
    Comment=Open Marchyo installation documentation
    Exec=${pkgs.firefox}/bin/firefox https://nixos.org/manual/nixos/stable/#sec-installation
    Icon=system-software-install
    Terminal=false
    Categories=System;
  '';

  # Additional Documentation Desktop Entry
  environment.etc."applications/marchyo-install.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Marchyo Installation Guide
    Comment=Quick start guide for installing Marchyo
    Exec=${pkgs.firefox}/bin/firefox https://nixos.org/manual/nixos/stable/
    Icon=emblem-documents
    Terminal=false
    Categories=System;Documentation;
  '';

  # Calamares Configuration for Marchyo
  services.calamares = {
    enable = true;
    settings = {
      # Branding
      branding = {
        componentName = "marchyo";
        strings = {
          productName = "Marchyo";
          shortProductName = "Marchyo";
          version = config.system.nixos.release;
          shortVersion = config.system.nixos.release;
          versionedName = "Marchyo ${config.system.nixos.release}";
          shortVersionedName = "Marchyo ${config.system.nixos.release}";
          bootloaderEntryName = "Marchyo";
        };
      };

      # Installation workflow
      sequence = [
        "welcome"
        "location"
        "keyboard"
        "partition"
        "users"
        "summary"
        "install"
        "finished"
      ];
    };
  };

  # Helpful Message on Login
  environment.etc."issue".text = lib.mkForce ''

    ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗ ██████╗
    ████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝██╔═══██╗
    ██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ ██║   ██║
    ██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝  ██║   ██║
    ██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ╚██████╔╝
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝

    Marchyo NixOS Graphical Installer

    Welcome! This live ISO includes:
    - Calamares graphical installer
    - Firefox for documentation browsing
    - GParted for disk partitioning
    - Full desktop environment (Plasma)
    - SSH server for remote assistance

    To start installation:
    1. Launch "Install Marchyo" from the desktop
    2. Or run: sudo calamares

    For manual installation, see: https://nixos.org/manual/nixos/stable/

    Auto-login enabled as user 'nixos' (no password required)

  '';

  # NetworkManager for easier network configuration
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false; # Disable wpa_supplicant in favor of NetworkManager

  # Additional User Configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    # No password required for live ISO
    initialHashedPassword = "";
  };

  # Sudo without password for convenience
  security.sudo.wheelNeedsPassword = false;
}
