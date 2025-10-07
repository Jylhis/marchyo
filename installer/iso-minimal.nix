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
  isoImage.isoName = lib.mkForce "marchyo-installer-minimal-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";

  # Console configuration - larger font for better readability
  console = {
    font = "ter-v24b";
    packages = [ pkgs.terminus_font ];
    earlySetup = true;
  };

  # Enable SSH for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Set a known root password for SSH access (change after first login!)
  users.users.root.initialPassword = "marchyo";

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

    Welcome to the Marchyo minimal installation environment!

    QUICK START:

    1. Clone the Marchyo repository:
       git clone https://github.com/marchyo/marchyo /tmp/marchyo
       cd /tmp/marchyo

    2. Partition your disk (manual or with disko):
       # Manual: Use fdisk, gdisk, or parted
       # Automated: nix run github:nix-community/disko -- --mode disko /path/to/disk-config.nix

    3. Generate hardware configuration:
       nixos-generate-config --root /mnt

    4. Customize and install:
       # Edit /mnt/etc/nixos/configuration.nix
       # Or use Marchyo configurations from the cloned repo
       nixos-install

    REMOTE INSTALLATION:

    SSH is enabled. Root password: marchyo (CHANGE THIS!)
    Find your IP with: ip addr
    Connect remotely: ssh root@<installer-ip>

    HELPFUL COMMANDS:

    - Disk tools: fdisk, gdisk, parted, cryptsetup
    - Filesystems: mkfs.btrfs, mkfs.ext4, zpool
    - Network: ping, ip, nmtui
    - Editors: vim, nano

    Documentation: https://nixos.org/manual/nixos/stable/

    ═══════════════════════════════════════════════════════════════

  '';

  # Environment variables and shell initialization
  environment.shellInit = ''
    # Marchyo repository location
    export MARCHYO_REPO="https://github.com/marchyo/marchyo"

    # Helpful aliases
    alias marchyo-clone='git clone $MARCHYO_REPO /tmp/marchyo'
    alias marchyo-install='cd /tmp/marchyo && echo "Ready to install! Check README for configuration options."'

    # Display installation hint
    if [ -z "$MARCHYO_HINT_SHOWN" ]; then
      export MARCHYO_HINT_SHOWN=1
      echo ""
      echo "TIP: Run 'marchyo-clone' to download the Marchyo configuration repository."
      echo ""
    fi
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

  system.stateVersion = "24.11";
}
