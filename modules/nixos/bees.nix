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
    ];

    # Forward each marchyo.bees entry to the upstream beesd module. Passing the
    # submodule fields explicitly keeps the marchyo surface decoupled from any
    # extra upstream options.
    services.beesd.filesystems = lib.mapAttrs (_name: fs: {
      inherit (fs)
        spec
        hashTableSizeMB
        verbosity
        extraOptions
        ;
    }) cfg.filesystems;
  };
}
