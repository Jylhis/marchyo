{ lib, ... }:
{
  options.marchyo.logging.journal = {
    maxUse = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "1G";
      description = ''
        Disk space the journal may use (`SystemMaxUse` in `journald.conf`).
        `null` keeps the journald default (10% of the filesystem, at most 4G).
      '';
    };

    retention = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "1month";
      description = ''
        Oldest journal entry to keep (`MaxRetentionSec` in `journald.conf`, a
        systemd time span). `null` keeps entries until `maxUse` is reached.
      '';
    };
  };
}
