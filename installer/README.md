# Marchyo NixOS Installer

This directory contains configuration files and scripts for installing NixOS with the Marchyo configuration.

## Prerequisites

- NixOS installation ISO booted on target machine
- Internet connection
- Target disk identified (e.g., `/dev/sda`, `/dev/nvme0n1`)

## Installation Methods

### Method 1: Automated Installation with Disko

The easiest method using automated disk partitioning:

```bash
# 1. Identify your target disk
lsblk

# 2. Run disko to partition and format the disk
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko /path/to/marchyo/installer/disko-config.nix \
  --arg disk '"/dev/sda"'

# 3. Generate hardware configuration
sudo nixos-generate-config --root /mnt

# 4. Clone this repository (if not already done)
cd /mnt/etc/nixos
sudo rm configuration.nix  # Remove default config
git clone https://github.com/yourusername/marchyo.git

# 5. Create a host configuration
# Edit /mnt/etc/nixos/marchyo/flake.nix and add your host configuration

# 6. Install NixOS
sudo nixos-install --flake /mnt/etc/nixos/marchyo#your-hostname

# 7. Reboot
sudo reboot
```

### Method 2: Manual Installation

For more control over the partitioning process:

1. **Partition the disk manually:**

```bash
# Create GPT partition table
sudo parted /dev/sda -- mklabel gpt

# Create ESP partition (512MB)
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sda -- set 1 esp on

# Create root partition (remaining space)
sudo parted /dev/sda -- mkpart primary btrfs 512MiB 100%

# Format ESP
sudo mkfs.fat -F 32 -n BOOT /dev/sda1

# Create Btrfs filesystem
sudo mkfs.btrfs -L nixos /dev/sda2
```

2. **Create Btrfs subvolumes:**

```bash
sudo mount /dev/sda2 /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@snapshots
sudo btrfs subvolume create /mnt/@swap
sudo umount /mnt
```

3. **Mount filesystems:**

```bash
# Mount root
sudo mount -o compress=zstd:3,noatime,space_cache=v2,subvol=@ /dev/sda2 /mnt

# Create mount points
sudo mkdir -p /mnt/{boot,home,nix,.snapshots,swap}

# Mount boot
sudo mount /dev/sda1 /mnt/boot

# Mount other subvolumes
sudo mount -o compress=zstd:3,noatime,space_cache=v2,subvol=@home /dev/sda2 /mnt/home
sudo mount -o compress=zstd:3,noatime,space_cache=v2,subvol=@nix /dev/sda2 /mnt/nix
sudo mount -o compress=zstd:3,noatime,space_cache=v2,subvol=@snapshots /dev/sda2 /mnt/.snapshots
sudo mount -o noatime,nodatacow,subvol=@swap /dev/sda2 /mnt/swap
```

4. **Create swap file (optional):**

```bash
sudo btrfs filesystem mkswapfile --size 8g /mnt/swap/swapfile
sudo swapon /mnt/swap/swapfile
```

5. **Continue with installation:**

Follow steps 3-7 from Method 1.

## Post-Installation

### Enable Btrfs Features

The `marchyo.btrfs.enable` option provides:
- Automatic monthly scrubbing
- Optimized mount options
- Subvolume management helpers

Enable in your configuration:

```nix
marchyo.btrfs = {
  enable = true;
  compression = "zstd";
  compressionLevel = 3;
  autoScrub = true;
};
```

### Set Up Snapshots (Optional)

Consider using `snapper` or `btrbk` for automatic snapshots:

```nix
# In your configuration.nix
services.snapper = {
  configs = {
    home = {
      SUBVOLUME = "/home";
      ALLOW_USERS = [ "yourusername" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
    };
  };
};
```

## Disk Layout

The default Btrfs layout:

- `@` → `/` (root filesystem)
- `@home` → `/home` (user data)
- `@nix` → `/nix` (Nix store)
- `@snapshots` → `/.snapshots` (snapshot storage)
- `@swap` → `/swap` (swap file location)

## Troubleshooting

### Disk not found
Ensure you're using the correct device path. Use `lsblk` to identify disks.

### Btrfs mount errors
Check that subvolumes are created correctly with:
```bash
sudo btrfs subvolume list /mnt
```

### Installation fails
Check logs with:
```bash
journalctl -xe
```

## Customization

Edit `disko-config.nix` to customize:
- Partition sizes
- Compression settings
- Subvolume layout
- Mount options

## References

- [Disko Documentation](https://github.com/nix-community/disko)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Btrfs Wiki](https://btrfs.wiki.kernel.org/)
