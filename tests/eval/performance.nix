{ helpers, lib, ... }:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    withTestUser
    ;
in
{
  # tuning.enable turns on the broadly-safe sub-toggles (network/nvme/memory).
  eval-performance-tuning-default = testNixOS "performance-tuning-default" (withTestUser {
    marchyo.performance.tuning.enable = true;
  });

  # Kernel selection maps the enum onto boot.kernelPackages (testNixOS never
  # forces that option). modDirVersion carries the zen localversion suffix
  # (e.g. "6.x.y-zen1"), which is more stable across nixpkgs revs than the
  # derivation name.
  eval-performance-kernel-zen =
    testNixOSCheck "performance-kernel-zen"
      (c: lib.hasInfix "zen" c.boot.kernelPackages.kernel.modDirVersion)
      (withTestUser {
        marchyo.performance.kernel = "zen";
      });

  # All toggles, including the aggressive hugePages + compute opt-ins.
  eval-performance-tuning-all = testNixOS "performance-tuning-all" (withTestUser {
    marchyo.performance.tuning = {
      enable = true;
      hugePages.enable = true;
      compute.enable = true;
    };
  });
}
