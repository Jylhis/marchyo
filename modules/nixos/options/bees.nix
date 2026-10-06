{ lib, ... }:
let
  inherit (lib) mkOption types;

  fsType = types.submodule (
    { config, ... }:
    {
      options = {
        spec = mkOption {
          type = types.str;
          example = "UUID=00000000-0000-0000-0000-000000000000";
          description = ''
            Identifier for the btrfs filesystem to deduplicate, in the same
            `findmnt` syntax as `fileSystems.<name>.device` — a `key=value` pair
            (`UUID=…`, `LABEL=…`, `PARTUUID=…`) or a mount path. A bare path also
            adds a systemd ordering dependency on the mount.
          '';
        };

        hashTableSizeMB = mkOption {
          type = types.int;
          default = 1024;
          description = ''
            Hash table size in MB (must be a positive multiple of 16). The table
            is locked into RAM, so every MB is permanently resident. A larger
            table recognises smaller duplicate extents. Per TB of unique data:
            128 MB gives ~128 KiB average dedupe extents (bees' recommended
            starting point), 256 MB ~64 KiB, 1024 MB ~16 KiB, 4096 MB ~4 KiB.
            Changing the size makes bees rebuild the table.
          '';
        };

        memoryHigh = mkOption {
          type = types.nullOr types.str;
          default = "${toString (config.hashTableSizeMB + 1024)}M";
          defaultText = lib.literalExpression ''"''${toString (hashTableSizeMB + 1024)}M"'';
          example = "3G";
          description = ''
            systemd `MemoryHigh=` for the bees unit. Bees reads every block on
            the filesystem, and without a limit the page cache it fills evicts
            other services into swap. Above this threshold the kernel throttles
            the cgroup and reclaims bees' own cache first; bees is not
            OOM-killed. The locked hash table counts against the limit, so keep
            it well above `hashTableSizeMB`. `null` leaves the cgroup unbounded.
          '';
        };

        threadCount = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          example = 4;
          description = ''
            Worker thread count (`--thread-count`). Fewer workers use less heap
            and fill the page cache more slowly. `null` keeps bees' default of
            one worker per CPU.
          '';
        };

        loadavgTarget = mkOption {
          type = types.nullOr (types.either types.ints.positive types.float);
          default = null;
          example = 8;
          description = ''
            Target system load average (`--loadavg-target`). Bees reduces its
            active workers while the load average is above this value. `null`
            disables load-based throttling.
          '';
        };

        verbosity = mkOption {
          type = types.str;
          default = "info";
          example = "debug";
          description = ''
            Log verbosity as a syslog keyword or level (`emerg`, `alert`, `crit`,
            `err`, `warning`, `notice`, `info`, `debug`, `trace`, or a numeric
            0–8). Forwarded to `services.beesd.filesystems.<name>.verbosity`.
          '';
        };

        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "--throttle-factor=2" ];
          description = "Extra command-line options passed to the bees daemon.";
        };
      };
    }
  );
in
{
  options.marchyo.bees = {
    enable = lib.mkEnableOption ''
      block-level deduplication for btrfs via the bees daemon
      (`services.beesd`). Bees is a background daemon that finds and removes
      duplicate extents across a btrfs filesystem, reclaiming space at the
      block level. It only works on btrfs, needs a persistent hash table
      (sized by `hashTableSizeMB`), and reads all data on the filesystem, so
      enable it deliberately per host. Declare at least one entry in
      `marchyo.bees.filesystems`'';

    filesystems = mkOption {
      type = types.attrsOf fsType;
      default = { };
      example = {
        root.spec = "UUID=00000000-0000-0000-0000-000000000000";
      };
      description = ''
        btrfs filesystems to run bees deduplication on, keyed by an arbitrary
        name. Each entry is forwarded to `services.beesd.filesystems.<name>`.
        There is no default filesystem — the `spec` (UUID/label/path) is
        host-specific, so you must name at least one when `enable = true`.
      '';
    };
  };
}
