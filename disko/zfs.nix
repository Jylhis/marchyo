# ZFS disk configuration
#
# Usage:
#   1. Set the disk device: export DISK=/dev/nvme0n1 (or /dev/sda, etc.)
#   2. Partition: sudo nix run github:nix-community/disko -- --mode disko disko/zfs.nix --arg device '"'$DISK'"'
#   3. Install NixOS normally
#   4. Add to configuration.nix:
#      boot.supportedFilesystems = [ "zfs" ];
#      networking.hostId = "$(head -c 8 /etc/machine-id)";
#
# Layout:
#   - ESP: 512MB FAT32 (/boot)
#   - ZFS pool "rpool" with datasets:
#     - rpool/root -> /      (system files, no snapshots)
#     - rpool/home -> /home  (user data, with snapshots)
#     - rpool/nix  -> /nix   (nix store, no snapshots)
#     - rpool/var  -> /var   (variable data)
#
# Features:
#   - Compression enabled (lz4 - fast and effective)
#   - atime disabled (better performance)
#   - No swap (ZFS uses ARC for caching)
#   - Dataset-level snapshots available
#
# Good for: servers, advanced users, data integrity focus
# Benefits: Advanced snapshot support, compression, checksumming, self-healing

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
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        rootFsOptions = {
          compression = "lz4";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };
        options = {
          ashift = "12";
          autotrim = "on";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              compression = "lz4";
              "com.sun:auto-snapshot" = "false";
            };
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              compression = "lz4";
              "com.sun:auto-snapshot" = "true";
            };
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              compression = "lz4";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options = {
              compression = "lz4";
              "com.sun:auto-snapshot" = "true";
            };
          };
        };
      };
    };
  };
}
