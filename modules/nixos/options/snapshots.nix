{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.snapshots = {
    enable = lib.mkEnableOption ''
      automatic filesystem snapshots via snapper (timeline + cleanup). Assumes a
      btrfs root by default; on a non-btrfs host set `btrfs = false` to disable
      all btrfs-specific configuration (snapper only works on btrfs, so the
      module then does nothing but warn)'';

    btrfs = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the root filesystem is btrfs. When true, snapper is configured
        for the `/` subvolume (a `/.snapshots` subvolume must exist on the host).
        Set false on ext4/zfs hosts to skip all btrfs-specific config.
      '';
    };

    subvolume = mkOption {
      type = types.str;
      default = "/";
      description = "Subvolume snapper takes timeline snapshots of.";
    };

    # A submodule, deliberately not `attrsOf int`: with an attrset default, one
    # `timelineLimits = { hourly = 24; }` replaces the whole default and every
    # other horizon becomes 0 while TIMELINE_CLEANUP stays on — snapper then
    # deletes the daily and longer-horizon snapshots. Per-field defaults make a
    # partial definition merge instead of destroying retention.
    timelineLimits = mkOption {
      type = types.submodule {
        options = {
          hourly = mkOption {
            type = types.ints.unsigned;
            default = 5;
            description = "Hourly timeline snapshots to keep.";
          };
          daily = mkOption {
            type = types.ints.unsigned;
            default = 7;
            description = "Daily timeline snapshots to keep.";
          };
          weekly = mkOption {
            type = types.ints.unsigned;
            default = 0;
            description = "Weekly timeline snapshots to keep.";
          };
          monthly = mkOption {
            type = types.ints.unsigned;
            default = 0;
            description = "Monthly timeline snapshots to keep.";
          };
          yearly = mkOption {
            type = types.ints.unsigned;
            default = 0;
            description = "Yearly timeline snapshots to keep.";
          };
        };
      };
      default = { };
      description = ''
        Number-cleanup timeline retention limits passed to snapper. Each
        horizon can be set on its own; the others keep their defaults.
      '';
    };
  };
}
