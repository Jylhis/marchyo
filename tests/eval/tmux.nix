# Themed tmux module (modules/home/tmux.nix, option in options/tmux.nix).
{
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) testNixOS testNixOSCheck withTestUser;
in
{
  eval-tmux = testNixOS "tmux" (withTestUser {
    marchyo.tmux.enable = true;
  });

  # Default follows marchyo.development.enable.
  eval-tmux-default-follows-development =
    testNixOSCheck "tmux-default-follows-development"
      (cfg: cfg.marchyo.tmux.enable && cfg.home-manager.users.testuser.programs.tmux.enable)
      (withTestUser {
        marchyo.development.enable = true;
      });

  eval-tmux-default-off = testNixOSCheck "tmux-default-off" (
    cfg: !cfg.marchyo.tmux.enable && !cfg.home-manager.users.testuser.programs.tmux.enable
  ) (withTestUser { });

  # Desktop: build-time colours plus the current-theme include, after them.
  eval-tmux-desktop-theme =
    testNixOSCheck "tmux-desktop-theme"
      (
        cfg:
        let
          tmux = cfg.home-manager.users.testuser.programs.tmux;
          extra = tmux.extraConfig;
          afterColours = lib.last (lib.splitString "display-panes-active-colour" extra);
        in
        tmux.mouse
        && tmux.keyMode == "vi"
        && tmux.terminal == "tmux-256color"
        && lib.hasInfix "terminal-overrides" extra
        && lib.hasInfix "marchyo/current-theme/tmux.conf" extra
        && lib.hasInfix "source-file -q" afterColours
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.tmux.enable = true;
      });

  # Headless: colours are baked in, no runtime include.
  eval-tmux-headless-theme =
    testNixOSCheck "tmux-headless-theme"
      (
        cfg:
        let
          extra = cfg.home-manager.users.testuser.programs.tmux.extraConfig;
        in
        lib.hasInfix "status-style" extra && !lib.hasInfix "current-theme" extra
      )
      (withTestUser {
        marchyo.tmux.enable = true;
      });
}
