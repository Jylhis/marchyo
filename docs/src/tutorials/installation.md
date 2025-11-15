# Installation Guide

This tutorial will guide you through installing NixOS with Marchyo from start to finish.

## Prerequisites

- A computer with at least:
  - 8GB RAM (16GB recommended)
  - 50GB free disk space
  - 64-bit x86 processor
- USB drive (4GB+) for the installer

## Step 1: Download the Installer ISO

Marchyo provides custom installer ISOs with all necessary tools pre-installed.

### Option A: Build from Source

```bash
# Clone the Marchyo repository
git clone https://github.com/Jylhis/marchyo.git
cd marchyo

# Build the minimal installer ISO
nix build .#nixosConfigurations.installer-minimal.config.system.build.isoImage

# The ISO will be in ./result/iso/
ls -lh result/iso/
```

### Option B: Download Pre-built ISO

Download the latest ISO from the [Marchyo releases](https://github.com/Jylhis/marchyo/releases) page.

## Step 2: Create Bootable USB

### On Linux

```bash
# Find your USB device (be careful!)
lsblk

# Write the ISO (replace /dev/sdX with your USB device)
sudo dd if=result/iso/marchyo-installer-minimal-*.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

### On macOS

```bash
# Find your USB device
diskutil list

# Unmount the disk (replace diskN)
diskutil unmountDisk /dev/diskN

# Write the ISO
sudo dd if=marchyo-installer-minimal-*.iso of=/dev/rdiskN bs=4m
```

### On Windows

Use [Rufus](https://rufus.ie/) or [balenaEtcher](https://www.balena.io/etcher/) to write the ISO to your USB drive.

## Step 3: Boot from USB

1. Insert the USB drive into your computer
2. Reboot and enter the boot menu (usually F12, F2, ESC, or DEL)
3. Select the USB drive from the boot menu
4. Wait for the installer to boot

You'll see the Marchyo ASCII logo and be dropped into a root shell.

## Step 4: Partition Your Disk

Marchyo provides disko configurations for easy disk setup.

### Simple UEFI Setup

```bash
# Set your target disk (replace /dev/sda with your disk)
export DISK=/dev/sda

# Download and apply the disko configuration
nix run github:nix-community/disko -- \
  --mode disko \
  --arg device "\"$DISK\"" \
  https://raw.githubusercontent.com/Jylhis/marchyo/main/disko/simple-uefi.nix
```

This creates:
- 512MB EFI boot partition
- 8GB swap partition (encrypted)
- Remaining space as root partition (ext4)

### Manual Partitioning

If you prefer manual control:

```bash
# Start gdisk for UEFI systems
gdisk /dev/sda

# Create partitions:
# Partition 1: 512MB EFI (type EF00)
# Partition 2: 8GB swap (type 8200)
# Partition 3: Remaining space (type 8300)

# Format the partitions
mkfs.fat -F 32 -n EFI /dev/sda1
mkswap -L swap /dev/sda2
mkfs.ext4 -L nixos /dev/sda3

# Mount the filesystems
mount /dev/sda3 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
swapon /dev/sda2
```

## Step 5: Generate Hardware Configuration

```bash
# Generate initial configuration
nixos-generate-config --root /mnt

# This creates:
# /mnt/etc/nixos/configuration.nix
# /mnt/etc/nixos/hardware-configuration.nix
```

## Step 6: Create Your Flake Configuration

```bash
# Create a flake-based configuration
cd /mnt/etc/nixos

# Create flake.nix
cat > flake.nix << 'EOF'
{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        marchyo.nixosModules.default
        ./hardware-configuration.nix
        ./configuration.nix
      ];
    };
  };
}
EOF

# Create configuration.nix
cat > configuration.nix << 'EOF'
{ config, pkgs, ... }:

{
  # Hostname
  networking.hostName = "myhostname";

  # Enable Marchyo features
  marchyo = {
    desktop.enable = true;
    development.enable = true;

    theme = {
      enable = true;
      variant = "dark";
      scheme = "modus-vivendi-tinted";
    };

    users.myuser = {
      enable = true;
      fullname = "Your Name";
      email = "your.email@example.com";
    };
  };

  # Create your user account
  users.users.myuser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  # Allow unfree packages (for Spotify, etc.)
  nixpkgs.config.allowUnfree = true;

  # System state version (don't change)
  system.stateVersion = "25.11";
}
EOF
```

## Step 7: Install NixOS

```bash
# Install the system
nixos-install --flake /mnt/etc/nixos#myhostname

# Set root password when prompted
```

## Step 8: Reboot

```bash
# Reboot into your new system
reboot
```

Remove the USB drive when the computer restarts.

## Step 9: First Login

1. Boot into your new NixOS system
2. You'll see the `tuigreet` login manager
3. Log in with your username and password
4. Hyprland will start automatically

## Next Steps

- [First Configuration](first-configuration.md) - Learn how to customize your system
- [Configure Desktop](../how-to/configure-desktop.md) - Customize Hyprland and desktop apps
- [Troubleshooting](../how-to/troubleshooting.md) - Solve common issues

## Troubleshooting

### Boot Fails

If the system doesn't boot:

1. Boot back into the installer USB
2. Mount your root partition:
   ```bash
   mount /dev/sda3 /mnt
   mount /dev/sda1 /mnt/boot
   ```
3. Check the configuration:
   ```bash
   nixos-enter
   nixos-rebuild dry-build --flake /etc/nixos#myhostname
   ```

### Forgot to Set Root Password

Boot from the installer and reset it:

```bash
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot
nixos-enter
passwd root
```

### Network Not Working

Add to your configuration:

```nix
networking.networkmanager.enable = true;
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#myhostname
```
