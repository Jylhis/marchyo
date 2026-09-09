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

  # mitigations=off is the shipped default, and setting the flag to false must
  # actually drop the kernel param (kernelParams is a list, so a stale
  # definition would silently concatenate rather than be overridden).
  eval-performance-mitigations-default = testNixOSCheck "performance-mitigations-default" (
    c: builtins.elem "mitigations=off" c.boot.kernelParams
  ) (withTestUser { });

  eval-performance-mitigations-off =
    testNixOSCheck "performance-mitigations-off"
      (c: !(builtins.elem "mitigations=off" c.boot.kernelParams))
      (withTestUser {
        marchyo.performance.disableMitigations = false;
      });

  # A host enabling podman directly (not via marchyo.development.enable) is in
  # the same position and must still get the warning.
  eval-performance-mitigations-warns-podman =
    testNixOSCheck "performance-mitigations-warns-podman"
      (c: builtins.any (w: lib.hasInfix "CPU mitigations are disabled" w) c.warnings)
      (withTestUser {
        virtualisation.podman.enable = true;
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
