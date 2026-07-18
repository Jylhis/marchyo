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
  # forces that option, so assert on the resolved kernel name).
  eval-performance-kernel-zen = testNixOSCheck "performance-kernel-zen" (
    c: lib.hasInfix "zen" c.boot.kernelPackages.kernel.name
  ) (withTestUser { marchyo.performance.kernel = "zen"; });

  # All toggles, including the aggressive hugePages + compute opt-ins.
  eval-performance-tuning-all = testNixOS "performance-tuning-all" (withTestUser {
    marchyo.performance.tuning = {
      enable = true;
      hugePages.enable = true;
      compute.enable = true;
    };
  });
}
