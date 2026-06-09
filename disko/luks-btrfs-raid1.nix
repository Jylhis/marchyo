# Two-disk BTRFS RAID1 with per-device LUKS2 encryption.
#
# Usage:
#   1. Set both disks:
#        export DISK_A=/dev/disk/by-id/nvme-...   # alphabetically first
#        export DISK_B=/dev/disk/by-id/nvme-...
#   2. Put your LUKS passphrase in /tmp/secret.key (or change passwordFile below
#      to use interactive entry).
#   3. Partition:
#        sudo nix run github:nix-community/disko -- --mode disko disko/luks-btrfs-raid1.nix \
#          --arg deviceA '"'$DISK_A'"' --arg deviceB '"'$DISK_B'"'
#   4. Install NixOS normally.
#
# Follows the upstream disko luks-btrfs-raid convention
# (https://github.com/nix-community/disko/blob/master/example/luks-btrfs-raid.nix):
# devices are formatted in alphabetical order and btrfs can only assemble a
# multi-device array once all members exist, so `mainA` carries an *empty* LUKS
# member (just provides /dev/mapper/cryptmainA) and `mainB` carries the actual
# btrfs filesystem definition, whose `extraArgs` reference the already-decrypted
# cryptmainA.
#
# Layout:
#   - mainA: ESP (1G, FAT32, mounted at /boot) + LUKS (empty member)
#   - mainB: reserved ESP (1G, FAT32, NOT mounted — for emergency bootctl install
#            if mainA dies) + LUKS containing the btrfs RAID1 filesystem
#   - BTRFS RAID1 data + RAID1 metadata; reads stripe across both drives:
#       /rootfs     -> /
#       /home       -> /home
#       /nix        -> /nix
#       /var/log    -> /var/log
#       /.snapshots -> /.snapshots   (snapshot stash, e.g. for btrbk)
#
# Performance stack:
#   - LUKS2 --sector-size 4096 (~5-10% small-I/O boost)
#   - --pbkdf argon2id with --pbkdf-memory capped at 512 MiB so key derivation is
#     deterministic across runs (the default auto-tunes to free memory and can
#     produce parameters that fail to verify on a busier `cryptsetup open`)
#   - bypassWorkqueues=true (no_read/write_workqueue; ~2x crypto on multi-drive)
#   - allowDiscards=true (TRIM through LUKS)
#   - mount opts: compress=zstd:3, noatime, ssd, discard=async, space_cache=v2, commit=120
#
# Two-passphrase note: at install both members share the same passphrase. To
# avoid a second initrd prompt, add a binary keyfile as a second keyslot on
# cryptmainB after install and reference it from
# boot.initrd.luks.devices.cryptmainB.keyFile in your host configuration.
#
# Swap: btrfs swapfiles are NOT supported on multi-device filesystems. Use zram
# (services.zramSwap or zramSwap.enable). For hibernation, add a dedicated swap
# partition outside the RAID1.
#
# Good for: laptops/desktops wanting full-disk encryption + drive redundancy.
{
  deviceA ? "/dev/sda",
  deviceB ? "/dev/sdb",
  ...
}:
let
  # LUKS2 format args shared by both members.
  luksFormatArgs = [
    "--sector-size"
    "4096"
    "--pbkdf"
    "argon2id"
    "--pbkdf-memory"
    "524288" # cap at 512 MiB — see header note
  ];
  luksSettings = {
    allowDiscards = true;
    bypassWorkqueues = true;
  };
  espContent = mountpoint: {
    type = "filesystem";
    format = "vfat";
    inherit mountpoint;
    mountOptions = [
      "fmask=0077"
      "dmask=0077"
    ];
  };
  btrfsMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "discard=async"
    "space_cache=v2"
    "commit=120"
  ];
in
{
  disko.devices = {
    disk = {
      # mainA — alphabetically first → ACTIVE BOOT + "empty LUKS" RAID1 member A.
      mainA = {
        type = "disk";
        device = deviceA;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = espContent "/boot";
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptmainA";
                # Change to interactive entry by removing passwordFile.
                passwordFile = "/tmp/secret.key";
                extraFormatArgs = luksFormatArgs;
                settings = luksSettings;
                # No content — empty member; the btrfs FS lives on mainB.
              };
            };
          };
        };
      };

      # mainB — alphabetically second → carries the btrfs RAID1 definition.
      mainB = {
        type = "disk";
        device = deviceB;
        content = {
          type = "gpt";
          partitions = {
            # Reserved ESP — formatted vfat but not mounted (boot redundancy).
            ESP_RESERVED = {
              priority = 1;
              name = "ESP_RES";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptmainB";
                passwordFile = "/tmp/secret.key";
                extraFormatArgs = luksFormatArgs;
                settings = luksSettings;
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "-f"
                    "-d"
                    "raid1"
                    "-m"
                    "raid1"
                    "-L"
                    "main"
                    "/dev/mapper/cryptmainA"
                  ];
                  subvolumes = {
                    "/rootfs" = {
                      mountpoint = "/";
                      mountOptions = btrfsMountOptions;
                    };
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = btrfsMountOptions;
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = btrfsMountOptions;
                    };
                    "/var/log" = {
                      mountpoint = "/var/log";
                      mountOptions = btrfsMountOptions;
                    };
                    "/.snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = btrfsMountOptions;
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
