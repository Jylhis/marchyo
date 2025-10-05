# Marchyo Minimal CLI Installer ISO
#
# This configuration builds a minimal, text-based installation ISO for Marchyo.
# It includes essential tools for installing NixOS with Marchyo configurations,
# supports both local and remote installations via SSH, and provides helpful
# guidance for users during the installation process.
#
# Build with: nix build .#nixosConfigurations.installer-minimal.config.system.build.isoImage

{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Enable flakes and nix-command for modern Nix features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # System identification
  networking.hostName = lib.mkForce "marchyo-installer";

  # ISO metadata
  image.fileName = lib.mkForce "marchyo-installer-minimal-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";

  # Enable SSH for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Set a known root password for SSH access (change after first login!)
  # users.users.root.initialPassword = "marchyo";

  # Essential installation tools
  environment.systemPackages = with pkgs; [
    # Version control
    git

    # Network utilities
    wget
    curl

    # Text editors
    vim
    nano

    # Partitioning tools
    gptfdisk
    parted

    # Filesystem tools
    cryptsetup
    btrfs-progs
    zfsUnstable

    # Disk management
    disko
  ];

  # Custom MOTD with Marchyo branding
  users.motd = ''

    ███╗   ███╗ █████╗ ██████╗  ██████╗██╗  ██╗██╗   ██╗ ██████╗
    ████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝██╔═══██╗
    ██╔████╔██║███████║██████╔╝██║     ███████║ ╚████╔╝ ██║   ██║
    ██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ╚██╔╝  ██║   ██║
    ██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ╚██████╔╝
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝

    ═══════════════════════════════════════════════════════════════
                        Marchyo Installer
    ═══════════════════════════════════════════════════════════════
  '';

  # Optimize for installation environment
  isoImage.squashfsCompression = "zstd -Xcompression-level 15";

  # Minimal documentation to keep ISO size down
  documentation = {
    enable = lib.mkForce true;
    doc.enable = lib.mkForce false;
    man.enable = lib.mkForce true;
    info.enable = lib.mkForce false;
  };

  system.stateVersion = "25.11";
}
