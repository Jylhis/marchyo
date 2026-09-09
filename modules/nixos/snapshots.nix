# Feature-gated: marchyo.snapshots.enable.
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
        # No `or 0` fallbacks: timelineLimits is a submodule, so every horizon
        # is always defined. The fallbacks are what turned a partial override
        # into silent snapshot deletion.
        TIMELINE_LIMIT_HOURLY = toString L.hourly;
        TIMELINE_LIMIT_DAILY = toString L.daily;
        TIMELINE_LIMIT_WEEKLY = toString L.weekly;
        TIMELINE_LIMIT_MONTHLY = toString L.monthly;
        TIMELINE_LIMIT_YEARLY = toString L.yearly;
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
