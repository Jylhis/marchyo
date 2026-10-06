{ lib, config, ... }:
let
  cfg = config.marchyo.bees;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.filesystems != { };
        message = ''
          marchyo.bees.enable is set but marchyo.bees.filesystems is empty. Bees
          needs at least one btrfs filesystem to deduplicate — declare one, e.g.
          marchyo.bees.filesystems.root.spec = "UUID=<your-btrfs-uuid>";
        '';
      }
    ]
    ++ lib.mapAttrsToList (name: fs: {
      assertion = fs.hashTableSizeMB > 0 && lib.mod fs.hashTableSizeMB 16 == 0;
      message = "marchyo.bees.filesystems.${name}.hashTableSizeMB must be a positive multiple of 16 (got ${toString fs.hashTableSizeMB}).";
    }) cfg.filesystems;

    services.beesd.filesystems = lib.mapAttrs (_name: fs: {
      inherit (fs)
        spec
        hashTableSizeMB
        verbosity
        ;
      extraOptions =
        fs.extraOptions
        ++ lib.optional (fs.threadCount != null) "--thread-count=${toString fs.threadCount}"
        ++ lib.optional (fs.loadavgTarget != null) "--loadavg-target=${toString fs.loadavgTarget}";
    }) cfg.filesystems;

    systemd.services = lib.mapAttrs' (
      name: fs: lib.nameValuePair "beesd@${name}" { serviceConfig.MemoryHigh = fs.memoryHigh; }
    ) (lib.filterAttrs (_: fs: fs.memoryHigh != null) cfg.filesystems);
  };
}
