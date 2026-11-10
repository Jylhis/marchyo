{ lib, ... }:
let
  mitigationsWarning = c: builtins.any (w: lib.hasInfix "CPU mitigations are disabled" w) c.warnings;
in
{
  refs = {
    # tuning.enable turns on the broadly-safe sub-toggles (network/nvme/memory)
    # (headless-tweaks-2).
    headless-tweaks-2.eval-performance-tuning-default = c: c.marchyo.performance.tuning.enable;

    # mitigations=off is the shipped default, and setting the flag to false must
    # actually drop the kernel param (kernelParams is a list, so a stale
    # definition would silently concatenate rather than be overridden).
    headless.eval-performance-mitigations-default =
      c: builtins.elem "mitigations=off" c.boot.kernelParams;

    # headless-tweaks: marchyo.performance.disableMitigations = false.
    headless-tweaks.eval-performance-mitigations-off =
      c: !(builtins.elem "mitigations=off" c.boot.kernelParams);

    # A host enabling podman directly (not via marchyo.development.enable) is in
    # the same position and must still get the warning (headless-tweaks-3:
    # virtualisation.podman.enable = true).
    headless-tweaks-3.eval-performance-mitigations-warns-podman = mitigationsWarning;

    # An explicit disableMitigations = true with a container runtime is an
    # acknowledged trade-off and must not warn (headless-tweaks-4: podman plus
    # the explicit flag).
    headless-tweaks-4 = {
      eval-performance-mitigations-explicit-silent = c: !(mitigationsWarning c);

      # All toggles, including the aggressive compute opt-in.
      eval-performance-tuning-all =
        c: c.marchyo.performance.tuning.hugePages.enable && c.marchyo.performance.tuning.compute.enable;
    };
  };

  refConfig = {
    headless-tweaks.marchyo.performance.disableMitigations = false;
    headless-tweaks-2.marchyo.performance.tuning.enable = true;
    headless-tweaks-3.virtualisation.podman.enable = true;
    headless-tweaks-4 = {
      virtualisation.podman.enable = true;
      marchyo.performance.disableMitigations = true;
      marchyo.performance.tuning = {
        enable = true;
        hugePages.enable = true;
        compute.enable = true;
      };
    };
  };
}
