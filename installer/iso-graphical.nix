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
  modulesPath,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
  ];

  # System Identification
  networking.hostName = "marchyo-installer-graphical";
  system.stateVersion = "25.11";

  # Enable Flakes and Modern Nix Commands
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Marchyo Branding
  image.fileName = lib.mkForce "marchyo-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage = {
    volumeID = lib.mkForce "MARCHYO_INSTALL";

    # Custom Plymouth splash screen (if available)
    makeEfiBootable = true;
    makeUsbBootable = true;
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
    gnome-disk-utility

    # Text Editors
    vim
    nano
    gedit
    # vscode  # Commented out due to large size (~300MB)

    # Terminal Emulators
    kitty
    alacritty

    # File Managers
    pcmanfm

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

  # Sudo without password for convenience
  security.sudo.wheelNeedsPassword = false;
}
