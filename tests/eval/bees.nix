{ helpers, ... }:
let
  inherit (helpers) testNixOSCheck testNixOSFails withTestUser;
in
{
  # A declared filesystem is forwarded to services.beesd, carrying the spec and
  # defaulted hashTableSizeMB, and the unit gets a MemoryHigh derived from it.
  eval-bees-enabled =
    testNixOSCheck "bees-enabled"
      (
        cfg:
        cfg.services.beesd.filesystems.root.spec == "UUID=test-uuid"
        && cfg.services.beesd.filesystems.root.hashTableSizeMB == 1024
        && cfg.services.beesd.filesystems.root.extraOptions == [ ]
        && cfg.systemd.services."beesd@root".serviceConfig.MemoryHigh == "2048M"
      )
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.root.spec = "UUID=test-uuid";
        };
      });

  # Per-filesystem overrides pass through to the upstream module. Assert on
  # fields with no upstream `apply` transform: hashTableSizeMB (int) and
  # extraOptions (list). Upstream's `verbosity` has an `apply` that maps the
  # syslog keyword to its numeric level, so its read-back value is not the
  # string set here — hence it is not asserted on directly.
  eval-bees-overrides =
    testNixOSCheck "bees-overrides"
      (
        cfg:
        cfg.services.beesd.filesystems.data.hashTableSizeMB == 4096
        &&
          cfg.services.beesd.filesystems.data.extraOptions == [
            "--throttle-factor=2"
            "--thread-count=2"
            "--loadavg-target=8"
          ]
        && cfg.systemd.services."beesd@data".serviceConfig.MemoryHigh == "5120M"
      )
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.data = {
            spec = "LABEL=data";
            hashTableSizeMB = 4096;
            threadCount = 2;
            loadavgTarget = 8;
            extraOptions = [ "--throttle-factor=2" ];
          };
        };
      });

  # An explicit memoryHigh is passed through verbatim.
  eval-bees-memoryhigh-explicit =
    testNixOSCheck "bees-memoryhigh-explicit"
      (cfg: cfg.systemd.services."beesd@root".serviceConfig.MemoryHigh == "3G")
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.root = {
            spec = "UUID=test-uuid";
            memoryHigh = "3G";
          };
        };
      });

  # memoryHigh = null leaves the unit without a MemoryHigh setting.
  eval-bees-memoryhigh-null =
    testNixOSCheck "bees-memoryhigh-null"
      (cfg: !(cfg.systemd.services."beesd@root".serviceConfig ? MemoryHigh))
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.root = {
            spec = "UUID=test-uuid";
            memoryHigh = null;
          };
        };
      });

  # Off by default: no beesd filesystems configured.
  eval-bees-disabled = testNixOSCheck "bees-disabled" (
    cfg: (cfg.services.beesd.filesystems or { }) == { }
  ) (withTestUser { });

  # Enabling without any filesystem trips the assertion.
  eval-bees-no-filesystem =
    testNixOSFails "bees-no-filesystem" "marchyo.bees.filesystems is empty"
      (withTestUser {
        marchyo.bees.enable = true;
      });

  # A hash table size that is not a multiple of 16 trips the assertion.
  eval-bees-bad-hash-size =
    testNixOSFails "bees-bad-hash-size" "hashTableSizeMB must be a positive multiple of 16"
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.root = {
            spec = "UUID=test-uuid";
            hashTableSizeMB = 1000;
          };
        };
      });
}
