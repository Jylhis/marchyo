# Unencrypted BTRFS with subvolumes
#
# Usage:
#   1. Set the disk device: export DISK=/dev/nvme0n1 (or /dev/sda, etc.)
#   2. Partition: sudo nix run github:nix-community/disko -- --mode disko disko/btrfs.nix --arg device '"'$DISK'"'
#   3. Install NixOS normally
#
# Layout:
#   - ESP: 512MB FAT32 (/boot)
#   - BTRFS with subvolumes:
#     - @root      -> /           (system files)
#     - @home      -> /home       (user data)
#     - @nix       -> /nix        (nix store)
#     - @persist   -> /persist    (for impermanence setups)
#     - @log       -> /var/log    (logs)
#     - @snapshots -> /.snapshots (snapshot storage)
#   - Swap: 8GB (random encryption; fresh key each boot)
#
# Good for: VMs, servers, machines that don't need disk encryption
# Benefits: Snapshot support, compression, no passphrase at boot

# No default: --mode disko repartitions and mkfs the target with no prompt,
# so falling back to /dev/sda would silently wipe whatever disk happens to be
# first on the host.
{
  device ? throw "disko/btrfs.nix: pass the target disk: --arg device '\"/dev/nvme0n1\"'",
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
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force overwrite
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
          };
        };
      };
    };
  };
}
