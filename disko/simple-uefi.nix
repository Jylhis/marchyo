# Simple UEFI disk configuration with ext4
#
# Usage:
#   1. Set the disk device: export DISK=/dev/nvme0n1 (or /dev/sda, etc.)
#   2. Partition: sudo nix run github:nix-community/disko -- --mode disko disko/simple-uefi.nix --arg device '"'$DISK'"'
#   3. Install NixOS normally
#
# Layout:
#   - ESP: 512MB FAT32 (/boot)
#   - Swap: 8GB
#   - Root: Remaining space, ext4 (/)
#
# This configuration is simple, reliable, and works everywhere.
# Good for: servers, VMs, machines without special requirements

# No default: --mode disko repartitions and mkfs the target with no prompt,
# so falling back to /dev/sda would silently wipe whatever disk happens to be
# first on the host.
{
  device ? throw "disko/simple-uefi.nix: pass the target disk: --arg device '\"/dev/nvme0n1\"'",
  ...
}:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                # Owner-only, matching disko/luks-btrfs-raid1.nix. vfat has no
                # permission bits of its own, and "defaults" leaves /boot
                # world-readable.
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
