{ lib, ... }:
let
  inherit (lib) mkOption types;

  fsType = types.submodule {
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
          Hash table size in MB (must be a multiple of 16). A larger table
          recognises smaller duplicate extents but uses more RAM: ~1024 MB per
          16 KiB granularity per TB of data is a common rule of thumb. The
          default (1024) recognises 16 KiB blocks; 4096 allows 4 KiB extents.
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
        example = [ "--thread-count=2" ];
        description = "Extra command-line options passed to the bees daemon.";
      };
    };
  };
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
