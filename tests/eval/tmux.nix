# Themed tmux module (modules/home/tmux.nix, option in options/tmux.nix).
{ lib, ... }:
let
  tmuxOn = cfg: cfg.marchyo.tmux.enable && cfg.home-manager.users.testuser.programs.tmux.enable;
in
{
  refs = {
    # headless-tweaks sets marchyo.tmux.enable = true.
    headless-tweaks = {
      eval-tmux = tmuxOn;

      # Headless: colours are baked in, no runtime include.
      eval-tmux-headless-theme =
        cfg:
        let
          extra = cfg.home-manager.users.testuser.programs.tmux.extraConfig;
        in
        lib.hasInfix "status-style" extra && !lib.hasInfix "current-theme" extra;
    };

    # Default follows marchyo.development.enable.
    headless-dev.eval-tmux-default-follows-development = tmuxOn;

    headless.eval-tmux-default-off =
      cfg: !cfg.marchyo.tmux.enable && !cfg.home-manager.users.testuser.programs.tmux.enable;

    # Desktop (full: development on, so tmux too): build-time colours plus the
    # current-theme include, after them.
    full.eval-tmux-desktop-theme =
      cfg:
      let
        tmux = cfg.home-manager.users.testuser.programs.tmux;
        extra = tmux.extraConfig;
        afterColours = lib.last (lib.splitString "display-panes-active-colour" extra);
      in
      cfg.marchyo.tmux.enable
      && tmux.mouse
      && tmux.keyMode == "vi"
      && tmux.terminal == "tmux-256color"
      && lib.hasInfix "terminal-overrides" extra
      && lib.hasInfix "marchyo/current-theme/tmux.conf" extra
      && lib.hasInfix "source-file -q" afterColours;
  };

  refConfig.headless-tweaks.marchyo.tmux.enable = true;
}
