_: {
  refs = {
    # tuning.enable turns on the broadly-safe sub-toggles (network/nvme/memory)
    # (headless-tweaks-2).
    headless-tweaks-2.eval-performance-tuning-default = c: c.marchyo.performance.tuning.enable;

    # Mitigations stay on by default.
    headless.eval-performance-mitigations-default =
      c: !(builtins.elem "mitigations=off" c.boot.kernelParams);

    # headless-tweaks: marchyo.performance.disableMitigations = true.
    headless-tweaks.eval-performance-mitigations-on-request =
      c: builtins.elem "mitigations=off" c.boot.kernelParams;

    # All toggles, including the aggressive compute opt-in (headless-tweaks-4).
    headless-tweaks-4.eval-performance-tuning-all =
      c: c.marchyo.performance.tuning.hugePages.enable && c.marchyo.performance.tuning.compute.enable;
  };

  refConfig = {
    headless-tweaks.marchyo.performance.disableMitigations = true;
    headless-tweaks-2.marchyo.performance.tuning.enable = true;
    headless-tweaks-4.marchyo.performance.tuning = {
      enable = true;
      hugePages.enable = true;
      compute.enable = true;
    };
  };
}
