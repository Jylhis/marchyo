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

    timelineLimits = mkOption {
      type = types.attrsOf types.int;
      default = {
        hourly = 5;
        daily = 7;
        weekly = 0;
        monthly = 0;
        yearly = 0;
      };
      description = "Number-cleanup timeline retention limits passed to snapper.";
    };
  };
}
