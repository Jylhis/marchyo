{ config, lib, ... }:
{
  options.marchyo.btrfs = {
    enable = lib.mkEnableOption "Btrfs filesystem configuration" // {
      default = false;
    };

    compression = lib.mkOption {
      type = lib.types.enum [
        "zstd"
        "lzo"
        "zlib"
        "none"
      ];
      default = "zstd";
      description = "Compression algorithm to use for Btrfs";
    };

    compressionLevel = lib.mkOption {
      type = lib.types.ints.between 1 15;
      default = 3;
      description = "Compression level (1-15, higher = more compression but slower)";
    };

    autoScrub = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic monthly Btrfs scrubbing";
    };

    subvolumes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Mount point for the subvolume";
              example = "/";
            };

            mountOptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Additional mount options for this subvolume";
              example = [ "noatime" ];
            };
          };
        }
      );
      default = {
        "@" = {
          mountPoint = "/";
          mountOptions = [ "noatime" ];
        };
        "@home" = {
          mountPoint = "/home";
          mountOptions = [ "noatime" ];
        };
        "@nix" = {
          mountPoint = "/nix";
          mountOptions = [ "noatime" ];
        };
        "@snapshots" = {
          mountPoint = "/.snapshots";
          mountOptions = [ "noatime" ];
        };
        "@swap" = {
          mountPoint = "/swap";
          mountOptions = [
            "noatime"
            "nodatacow"
          ];
        };
      };
      description = ''
        Btrfs subvolume configuration.
        This is a declarative description only - actual subvolume creation
        must be done during installation.
      '';
    };
  };

  config = lib.mkIf config.marchyo.btrfs.enable {
    # Enable Btrfs support in boot
    boot.supportedFilesystems = [ "btrfs" ];

    # Auto-scrub for Btrfs filesystems
    services.btrfs.autoScrub = lib.mkIf config.marchyo.btrfs.autoScrub {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ]; # Adjust based on your setup
    };

    # Common Btrfs mount options
    # Note: This is a helper - actual fileSystems configuration should be in hardware-configuration.nix
    # Users should reference config.marchyo.btrfs.compression and other options there
  };
}
