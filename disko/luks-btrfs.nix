# LUKS encrypted BTRFS with subvolumes
#
# Usage:
#   1. Set the disk device: export DISK=/dev/nvme0n1 (or /dev/sda, etc.)
#   2. Partition: sudo nix run github:nix-community/disko -- --mode disko disko/luks-btrfs.nix --arg device '"'$DISK'"'
#   3. During partitioning, you'll be prompted to set a LUKS passphrase
#   4. Install NixOS normally
#
# Layout:
#   - ESP: 512MB FAT32 (/boot)
#   - LUKS encrypted container containing:
#     - BTRFS with subvolumes:
#       - @root      -> /           (system files)
#       - @home      -> /home       (user data)
#       - @nix       -> /nix        (nix store)
#       - @persist   -> /persist    (for impermanence setups)
#       - @log       -> /var/log    (logs)
#       - @snapshots -> /.snapshots (snapshot storage)
#   - Swap: 8GB (encrypted)
#
# Good for: laptops, desktops, privacy-focused setups
# Benefits: Full disk encryption, snapshot support, compression

{
  device ? "/dev/sda",
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
                mountOptions = [ "defaults" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # Disable settings.keyFile if you want to use interactive password entry
                passwordFile = "/tmp/secret.key"; # Change this to your key file location
                settings = {
                  allowDiscards = true;
                  bypassWorkqueues = true;
                };
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
