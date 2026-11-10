# marchyo.bees. headless-tweaks declares filesystems.root (spec only) and
# filesystems.data (every override); headless-tweaks-2 and -3 declare root
# with memoryHigh = "3G" and null.
_: {
  refs = {
    headless-tweaks = {
      # A declared filesystem is forwarded to services.beesd, carrying the spec
      # and defaulted hashTableSizeMB, and the unit gets a MemoryHigh derived
      # from it.
      eval-bees-enabled =
        cfg:
        cfg.services.beesd.filesystems.root.spec == "UUID=test-uuid"
        && cfg.services.beesd.filesystems.root.hashTableSizeMB == 1024
        && cfg.services.beesd.filesystems.root.extraOptions == [ ]
        && cfg.systemd.services."beesd@root".serviceConfig.MemoryHigh == "2048M";

      # Per-filesystem overrides pass through to the upstream module. Assert on
      # fields with no upstream `apply` transform: hashTableSizeMB (int) and
      # extraOptions (list). Upstream's `verbosity` has an `apply` that maps the
      # syslog keyword to its numeric level, so its read-back value is not the
      # string set here — hence it is not asserted on directly.
      eval-bees-overrides =
        cfg:
        cfg.services.beesd.filesystems.data.hashTableSizeMB == 4096
        &&
          cfg.services.beesd.filesystems.data.extraOptions == [
            "--throttle-factor=2"
            "--thread-count=2"
            "--loadavg-target=8"
          ]
        && cfg.systemd.services."beesd@data".serviceConfig.MemoryHigh == "5120M";
    };

    # An explicit memoryHigh is passed through verbatim.
    headless-tweaks-2.eval-bees-memoryhigh-explicit =
      cfg: cfg.systemd.services."beesd@root".serviceConfig.MemoryHigh == "3G";

    # memoryHigh = null leaves the unit without a MemoryHigh setting.
    headless-tweaks-3.eval-bees-memoryhigh-null =
      cfg: !(cfg.systemd.services."beesd@root".serviceConfig ? MemoryHigh);

    # Off by default: no beesd filesystems configured.
    headless.eval-bees-disabled = cfg: (cfg.services.beesd.filesystems or { }) == { };
  };

  failing = {
    # Enabling without any filesystem trips the assertion (misconfigured:
    # marchyo.bees.enable with no filesystems).
    eval-bees-no-filesystem = {
      on = "misconfigured";
      expect = "marchyo.bees.filesystems is empty";
    };

    # A hash table size that is not a multiple of 16 trips the assertion
    # (misconfigured-2).
    eval-bees-bad-hash-size = {
      on = "misconfigured-2";
      expect = "hashTableSizeMB must be a positive multiple of 16";
    };
  };

  failingConfig = {
    misconfigured.marchyo.bees.enable = true;
    misconfigured-2.marchyo.bees = {
      enable = true;
      filesystems.root = {
        spec = "UUID=test-uuid";
        hashTableSizeMB = 1000;
      };
    };
  };

  refConfig = {
    headless-tweaks.marchyo.bees = {
      enable = true;
      filesystems.root.spec = "UUID=test-uuid";
      filesystems.data = {
        spec = "LABEL=data";
        hashTableSizeMB = 4096;
        threadCount = 2;
        loadavgTarget = 8;
        extraOptions = [ "--throttle-factor=2" ];
      };
    };
    headless-tweaks-2.marchyo.bees = {
      enable = true;
      filesystems.root = {
        spec = "UUID=test-uuid";
        memoryHigh = "3G";
      };
    };
    headless-tweaks-3.marchyo.bees = {
      enable = true;
      filesystems.root = {
        spec = "UUID=test-uuid";
        memoryHigh = null;
      };
    };
  };
}
