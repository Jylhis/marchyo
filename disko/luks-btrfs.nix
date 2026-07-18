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
#   - Swap: 32GB (randomEncryption — NO hibernation/resume support, see below)
#
# Good for: laptops, desktops, privacy-focused setups
# Benefits: Full disk encryption, snapshot support, compression
#
# Hibernation: this variant does NOT support resume-from-disk as shipped. The
# swap partition sits OUTSIDE the LUKS container and uses randomEncryption,
# which re-keys swap with a fresh random key on every boot — the hibernation
# image can never be read back. Hibernation also needs swap >= RAM (the 32G
# sizing below covers that once the encryption question is solved). To get
# working hibernation, either put swap inside the encryption (LVM-on-LUKS or a
# btrfs swapfile in the LUKS container) or accept plaintext swap by setting
# randomEncryption = false — then point marchyo.power.hibernation.resumeDevice
# at the swap device.

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
                name = "encrypted";
                # Recommended: remove passwordFile entirely for interactive
                # passphrase entry at partition time. If you must use a key file,
                # keep it out of world-readable /tmp — write it to a root-only
                # path (`umask 077; printf %s "$pass" > /root/secret.key`) and
                # delete it after install.
                passwordFile = "/root/secret.key"; # change to your key file location
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
              # Sized >= typical RAM so the layout is hibernation-ready once
              # the encryption caveat is addressed (hibernation needs
              # swap >= RAM to hold the resume image).
              size = "32G";
              content = {
                type = "swap";
                # Kept true: this partition is outside the LUKS container, so
                # turning randomEncryption off would leave swap PLAINTEXT next
                # to an otherwise encrypted disk. The trade-off: a fresh random
                # key per boot means resume-from-disk (hibernation) cannot
                # work with this layout — see the header comment for
                # hibernation-capable alternatives.
                randomEncryption = true;
              };
            };
          };
        };
      };
    };
  };
}
