# The emacs module evaluates (assertions pass) off, on, and with every
# sub-feature off (desktop-tweaks sets marchyo.emacs.enable with windmove,
# eventListener, scratchpad, everywhere and orgProtocol all disabled).
_: {
  refs = {
    desktop.eval-emacs-disabled = _: true;
    full.eval-emacs-enabled = cfg: cfg.marchyo.emacs.enable;
    desktop-tweaks.eval-emacs-minimal =
      cfg: cfg.marchyo.emacs.enable && !cfg.marchyo.emacs.windmove.enable;
  };

  refConfig.desktop-tweaks.marchyo.emacs = {
    enable = true;
    windmove.enable = false;
    eventListener.enable = false;
    scratchpad.enable = false;
    everywhere.enable = false;
    orgProtocol.enable = false;
  };
}
