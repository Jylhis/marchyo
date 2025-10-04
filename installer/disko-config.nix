# Disko configuration for automated disk partitioning
# This provides a declarative disk layout for NixOS installation
#
# Usage:
#   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
#     --mode disko /path/to/this/file.nix --arg disk '"/dev/sda"'

{
  disk ? "/dev/sda",
  ...
}:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            # ESP (EFI System Partition)
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
              };
            };

            # Main Btrfs partition
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force overwrite
                subvolumes = {
                  # Root subvolume
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "space_cache=v2"
                    ];
                  };

                  # Home subvolume
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "space_cache=v2"
                    ];
                  };

                  # Nix store subvolume
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "space_cache=v2"
                    ];
                  };

                  # Snapshots subvolume
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "space_cache=v2"
                    ];
                  };

                  # Swap subvolume (no COW for swap)
                  "@swap" = {
                    mountpoint = "/swap";
                    mountOptions = [
                      "noatime"
                      "nodatacow"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };

    # Swap file configuration
    # Note: Swap file will need to be created manually after installation:
    # sudo btrfs filesystem mkswapfile --size 8g /swap/swapfile
    # sudo swapon /swap/swapfile
  };
}
