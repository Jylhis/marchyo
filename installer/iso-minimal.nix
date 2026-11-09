# Marchyo Minimal CLI Installer ISO
#
# This configuration builds a minimal, text-based installation ISO for Marchyo.
# It includes essential tools for installing NixOS with Marchyo configurations,
# supports both local and remote installations via SSH, and provides helpful
# guidance for users during the installation process.
#
# Flake output packages.x86_64-linux.iso-minimal; `nix flake check` evaluates
# its drvPath (checks.x86_64-linux.eval-iso-minimal) without building it. Build:
#
#   just iso minimal   # or: nix build .#iso-minimal

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
  networking.hostName = "marchyo-installer";

  # ISO metadata
  image.fileName = lib.mkForce "marchyo-installer-minimal-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";

  # Key-only SSH for remote installation: a password-reachable root on a
  # live image is a remote-root hole. Add your own key to reach the image.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA... you@host" ];

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
    zfs_unstable

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
