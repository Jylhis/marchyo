{ lib, config, ... }:
let
  cfg = config.marchyo.snapshots;
  mUsers = builtins.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
  L = cfg.timelineLimits;
in
{
  config = lib.mkMerge [
    # btrfs host: configure snapper for the root subvolume.
    (lib.mkIf (cfg.enable && cfg.btrfs) {
      services.snapper.configs.root = {
        SUBVOLUME = cfg.subvolume;
        ALLOW_USERS = mUsers;
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = toString (L.hourly or 0);
        TIMELINE_LIMIT_DAILY = toString (L.daily or 0);
        TIMELINE_LIMIT_WEEKLY = toString (L.weekly or 0);
        TIMELINE_LIMIT_MONTHLY = toString (L.monthly or 0);
        TIMELINE_LIMIT_YEARLY = toString (L.yearly or 0);
      };
    })

    # Non-btrfs host: snapper cannot run, so warn instead of applying config.
    (lib.mkIf (cfg.enable && !cfg.btrfs) {
      warnings = [
        "marchyo.snapshots.enable is set but marchyo.snapshots.btrfs = false; snapper only supports btrfs, so no snapshot configuration was applied."
      ];
    })
  ];
}
