{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  # tuning.enable turns on the broadly-safe sub-toggles (network/nvme/memory).
  eval-performance-tuning-default = testNixOS "performance-tuning-default" (withTestUser {
    marchyo.performance.tuning.enable = true;
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
