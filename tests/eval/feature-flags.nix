# The feature flags evaluate (assertions pass) alone and together.
_: {
  refs = {
    minimal.eval-minimal = _: true;
    desktop.eval-desktop = cfg: cfg.marchyo.desktop.enable;
    # minimal-tweaks is minimalConfig (no user) with development on.
    minimal-tweaks = {
      eval-development = cfg: cfg.marchyo.development.enable;
      # Development without desktop stays headless.
      eval-development-no-desktop = cfg: !cfg.marchyo.desktop.enable;
    };
    full.eval-all-features =
      cfg:
      cfg.marchyo.desktop.enable
      && cfg.marchyo.development.enable
      && cfg.marchyo.media.enable
      && cfg.marchyo.office.enable;
  };

  refConfig.minimal-tweaks.marchyo.development.enable = true;
}
