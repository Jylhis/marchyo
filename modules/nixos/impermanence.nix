# Impermanence Module - BTRFS Root Rollback on Boot
#
# ============================================================================
# WHAT IS IMPERMANENCE?
# ============================================================================
#
# Impermanence is a NixOS configuration pattern that implements a stateless root
# filesystem by rolling back to a blank snapshot on every boot. This provides:
#
# - Guaranteed clean state after every reboot
# - Protection against persistent malware and system corruption
# - Explicit control over what persists between reboots
# - Easy system recovery (just reboot to get back to known-good state)
#
# The root filesystem is rolled back to a blank snapshot on boot, while selected
# directories (like /home, /var/log, etc.) are persisted on a separate BTRFS
# subvolume that survives the rollback.
#
# ============================================================================
# HOW TO SET UP INITIAL SNAPSHOTS
# ============================================================================
#
# 1. Create BTRFS subvolumes during installation:
#    # Mount your BTRFS partition
#    mount /dev/sdX /mnt
#
#    # Create subvolumes
#    btrfs subvolume create /mnt/@root        # Active root
#    btrfs subvolume create /mnt/@persist     # Persistent data
#    btrfs subvolume create /mnt/@nix         # Nix store (optional but recommended)
#    btrfs subvolume create /mnt/@swap        # Swap (if using swapfile)
#
#    # Create blank snapshot
#    btrfs subvolume snapshot -r /mnt/@root /mnt/@blank
#
#    # Mount subvolumes
#    umount /mnt
#    mount -o subvol=@root /dev/sdX /mnt
#    mkdir -p /mnt/{persist,nix,swap}
#    mount -o subvol=@persist /dev/sdX /mnt/persist
#    mount -o subvol=@nix /dev/sdX /mnt/nix
#    mount -o subvol=@swap /dev/sdX /mnt/swap
#
# 2. In your hardware-configuration.nix, ensure mounts are configured:
#    fileSystems."/" = {
#      device = "/dev/disk/by-uuid/YOUR-UUID";
#      fsType = "btrfs";
#      options = [ "subvol=@root" "compress=zstd" "noatime" ];
#    };
#
#    fileSystems."/persist" = {
#      device = "/dev/disk/by-uuid/YOUR-UUID";
#      fsType = "btrfs";
#      options = [ "subvol=@persist" "compress=zstd" "noatime" ];
#      neededForBoot = true;  # IMPORTANT: Required for impermanence
#    };
#
#    fileSystems."/nix" = {
#      device = "/dev/disk/by-uuid/YOUR-UUID";
#      fsType = "btrfs";
#      options = [ "subvol=@nix" "compress=zstd" "noatime" ];
#    };
#
# 3. Enable this module in your configuration:
#    marchyo.impermanence.enable = true;
#
# 4. Deploy and reboot - your root will now rollback on every boot!
#
# ============================================================================
# HOW TO ADD PERSISTENT PATHS
# ============================================================================
#
# System-wide persistent directories (add to persistentDirs):
#   marchyo.impermanence.persistentDirs = [
#     "/etc/NetworkManager/system-connections"  # WiFi passwords
#     "/var/lib/bluetooth"                      # Bluetooth pairings
#     "/var/lib/docker"                         # Docker data
#   ];
#
# User home directories are handled separately via Home Manager's
# impermanence module. This system module only handles system-level paths.
#
# ============================================================================
# RECOVERY PROCEDURES
# ============================================================================
#
# If something breaks during boot:
#
# 1. Boot from NixOS installation media
# 2. Mount your BTRFS partition:
#    mount /dev/sdX /mnt
# 3. Examine or restore the blank snapshot:
#    # View current root
#    ls /mnt/@root
#    # Delete corrupted root and restore from blank
#    btrfs subvolume delete /mnt/@root
#    btrfs subvolume snapshot /mnt/@blank /mnt/@root
# 4. Check your persistent data (should be unaffected):
#    ls /mnt/@persist
# 5. Reboot
#
# If you need to update the blank snapshot (after intentional system changes):
#   1. Boot into system
#   2. Make your changes
#   3. Delete old blank and create new one:
#      sudo btrfs subvolume delete /@blank
#      sudo btrfs subvolume snapshot -r / /@blank
#   4. Reboot to test
#
# ============================================================================

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    mkMerge
    types
    literalExpression
    ;
  cfg = config.marchyo.impermanence;

  # Script to rollback root subvolume to blank snapshot on boot
  rollbackScript = pkgs.writeShellScript "rollback-root" ''
    set -euo pipefail

    # Wait for device to be available
    echo "Waiting for root device..."
    while [ ! -e "${cfg.device}" ]; do
      sleep 0.1
    done

    echo "Rolling back root filesystem to blank snapshot..."

    # Create a temporary mount point
    mkdir -p /tmp/btrfs-root
    mount -t btrfs -o subvol=/ "${cfg.device}" /tmp/btrfs-root

    # Check if blank snapshot exists
    if [ ! -e "/tmp/btrfs-root/${cfg.blankSnapshotPath}" ]; then
      echo "ERROR: Blank snapshot '${cfg.blankSnapshotPath}' not found!"
      echo "Please create it with: btrfs subvolume snapshot -r / /@blank"
      umount /tmp/btrfs-root
      rmdir /tmp/btrfs-root
      exit 1
    fi

    # Delete old root subvolume and restore from blank
    echo "Deleting old root subvolume..."
    btrfs subvolume delete /tmp/btrfs-root/${cfg.rootSubvolume} || true

    echo "Restoring root from blank snapshot..."
    btrfs subvolume snapshot /tmp/btrfs-root/${cfg.blankSnapshotPath} /tmp/btrfs-root/${cfg.rootSubvolume}

    # Cleanup
    umount /tmp/btrfs-root
    rmdir /tmp/btrfs-root

    echo "Root filesystem rollback complete!"
  '';
in
{
  options.marchyo.impermanence = {
    enable = mkEnableOption "BTRFS root rollback on boot (impermanence)";

    device = mkOption {
      type = types.str;
      example = "/dev/disk/by-uuid/12345678-1234-1234-1234-123456789012";
      description = ''
        Device path for the BTRFS filesystem containing root and persist subvolumes.
        Use /dev/disk/by-uuid/... for reliability across boots.
      '';
    };

    rootSubvolume = mkOption {
      type = types.str;
      default = "@root";
      example = "@root";
      description = ''
        Name of the BTRFS subvolume used for the root filesystem.
        This subvolume will be deleted and recreated from the blank snapshot on every boot.
      '';
    };

    persistSubvolume = mkOption {
      type = types.str;
      default = "@persist";
      example = "@persist";
      description = ''
        Name of the BTRFS subvolume used for persistent data.
        This subvolume survives rollbacks and should be mounted at /persist.
      '';
    };

    blankSnapshotPath = mkOption {
      type = types.str;
      default = "@blank";
      example = "@blank";
      description = ''
        Name of the read-only BTRFS snapshot representing the blank root state.
        Create with: btrfs subvolume snapshot -r / /@blank
      '';
    };

    persistHome = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to persist the /home directory.
        If false, user home directories will be wiped on every boot (use with caution!).
      '';
    };

    persistentDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = literalExpression ''
        [
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
          "/var/lib/docker"
        ]
      '';
      description = ''
        Additional directories to persist across reboots.
        These will be symlinked from /persist to their original locations.

        Common directories you might want to persist:
        - /etc/NetworkManager/system-connections (WiFi passwords)
        - /etc/ssh (SSH host keys)
        - /var/lib/bluetooth (Bluetooth pairings)
        - /var/lib/docker (Docker data)
        - /var/lib/libvirt (VM images)
        - /var/lib/postgres (PostgreSQL databases)
        - /root (root user home, if not using home manager)
      '';
    };

    defaultPersistentDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "/etc/nixos" # NixOS configuration
        "/var/log" # System logs
        "/var/lib/systemd" # Systemd state (timers, etc.)
        "/var/lib/nixos" # NixOS state
      ];
      description = ''
        Default directories that are always persisted.
        These are essential for NixOS to function correctly.
        Override this option only if you know what you're doing.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Main impermanence configuration
    {
      # Verify device is specified
      assertions = [
        {
          assertion = cfg.device != "";
          message = "marchyo.impermanence.device must be set to your BTRFS device path";
        }
      ];

      # Create systemd service to rollback root on boot
      systemd.services.rollback-root = {
        description = "Rollback BTRFS root subvolume to blank snapshot";
        wantedBy = [ "local-fs.target" ];
        requires = [ "local-fs-pre.target" ];
        after = [ "local-fs-pre.target" ];
        before = [
          "local-fs.target"
          "sysinit.target"
        ];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${rollbackScript}";
        };
      };

      # Bind mount persistent directories to their expected locations
      # This creates the directory structure in /persist and symlinks them
      fileSystems =
        let
          allPersistentDirs =
            cfg.defaultPersistentDirs ++ cfg.persistentDirs ++ (if cfg.persistHome then [ "/home" ] else [ ]);

          # Create fileSystems entries for each persistent directory
          mkPersistentMount = dir: {
            name = dir;
            value = {
              device = "/persist${dir}";
              fsType = "none";
              options = [
                "bind"
                "X-fstrim.notrim"
              ];
              depends = [ "/persist" ];
            };
          };
        in
        builtins.listToAttrs (map mkPersistentMount allPersistentDirs);

      # Create parent directories in /persist on activation
      # This ensures the bind mounts have a target to bind to
      system.activationScripts.createPersistentDirs = lib.mkAfter ''
        echo "Creating persistent directory structure..."
        ${lib.concatMapStringsSep "\n"
          (dir: ''
            mkdir -p "/persist${dir}"
          '')
          (cfg.defaultPersistentDirs ++ cfg.persistentDirs ++ (if cfg.persistHome then [ "/home" ] else [ ]))
        }
      '';

      # Warning if the system doesn't appear to have /persist mounted
      warnings =
        let
          hasPersistMount = builtins.any (fs: fs.mountPoint == "/persist") (
            builtins.attrValues config.fileSystems
          );
        in
        lib.optional (!hasPersistMount) ''
          marchyo.impermanence is enabled but /persist is not configured in fileSystems.
          Please add /persist mount in your hardware-configuration.nix:

            fileSystems."/persist" = {
              device = "${cfg.device}";
              fsType = "btrfs";
              options = [ "subvol=${cfg.persistSubvolume}" "compress=zstd" "noatime" ];
              neededForBoot = true;
            };
        '';
    }

    # Additional warnings about BTRFS
    {
      warnings =
        let
          rootFsType = config.fileSystems."/".fsType or "";
          isBtrfs = rootFsType == "btrfs";
        in
        lib.optional (!isBtrfs) ''
          marchyo.impermanence is enabled but root filesystem is not BTRFS (detected: ${rootFsType}).
          This module requires BTRFS with subvolumes. If you're using BTRFS but seeing this warning,
          ensure your root fileSystems entry has fsType = "btrfs".
        '';
    }
  ]);
}
