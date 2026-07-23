{ helpers, ... }:
let
  inherit (helpers) testNixOSCheck testNixOSFails withTestUser;
in
{
  # A declared filesystem is forwarded to services.beesd, carrying the spec and
  # defaulted hashTableSizeMB.
  eval-bees-enabled =
    testNixOSCheck "bees-enabled"
      (
        cfg:
        cfg.services.beesd.filesystems.root.spec == "UUID=test-uuid"
        && cfg.services.beesd.filesystems.root.hashTableSizeMB == 1024
      )
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.root.spec = "UUID=test-uuid";
        };
      });

  # Per-filesystem overrides pass through to the upstream module.
  eval-bees-overrides =
    testNixOSCheck "bees-overrides"
      (
        cfg:
        cfg.services.beesd.filesystems.data.hashTableSizeMB == 4096
        && cfg.services.beesd.filesystems.data.verbosity == "debug"
      )
      (withTestUser {
        marchyo.bees = {
          enable = true;
          filesystems.data = {
            spec = "LABEL=data";
            hashTableSizeMB = 4096;
            verbosity = "debug";
          };
        };
      });

  # Off by default: no beesd filesystems configured.
  eval-bees-disabled =
    testNixOSCheck "bees-disabled" (cfg: (cfg.services.beesd.filesystems or { }) == { })
      (withTestUser { });

  # Enabling without any filesystem trips the assertion.
  eval-bees-no-filesystem =
    testNixOSFails "bees-no-filesystem" "marchyo.bees.filesystems is empty"
      (withTestUser {
        marchyo.bees.enable = true;
      });
}
