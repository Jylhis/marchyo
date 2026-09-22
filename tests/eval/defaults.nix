{ helpers, ... }:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    withTestUser
    ;
in
{
  eval-defaults-browser = testNixOS "defaults-browser" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = "google-chrome";
  });

  eval-defaults-editor = testNixOS "defaults-editor" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.editor = "emacs";
    marchyo.defaults.terminalEditor = "emacs";
  });

  # All defaults set to null = marchyo manages nothing.
  eval-defaults-null = testNixOS "defaults-null" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = null;
    marchyo.defaults.editor = null;
    marchyo.defaults.terminalEditor = null;
    marchyo.defaults.videoPlayer = null;
    marchyo.defaults.audioPlayer = null;
    marchyo.defaults.musicPlayer = null;
    marchyo.defaults.fileManager = null;
    marchyo.defaults.terminalFileManager = null;
    marchyo.defaults.imageEditor = null;
    marchyo.defaults.email = null;
  });

  eval-defaults-all = testNixOS "defaults-all" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults = {
      browser = "firefox";
      editor = "vscode";
      terminalEditor = "neovim";
      videoPlayer = "vlc";
      audioPlayer = "vlc";
      musicPlayer = "spotify";
      fileManager = "thunar";
      terminalFileManager = "ranger";
      imageEditor = "gimp";
      email = "gmail";
    };
  });

  # TUI-flipped defaults: spotify-player (music), cmus (audio), aerc (email).
  eval-defaults-tui = testNixOS "defaults-tui" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults = {
      musicPlayer = "spotify-player";
      audioPlayer = "cmus";
      email = "aerc";
    };
  });

  # aerc styleset regression: marchyo hand-rolls its own styleset (the Stylix
  # aerc target is disabled in modules/generic/theme.nix) because upstream used
  # base07 (= surface-raised, near-white in Sheet) as a *foreground*, giving
  # white-on-white unread subjects / title / header in the light variant. Assert
  # (in the light variant) that the styleset is named "marchyo", that unread
  # subjects / title / selected-tab share the heading ink, and — the crux — that
  # that ink is NOT the near-white surface-raised (which the styleset reuses only
  # as completion_pill.bg, a background). Kept config-relative so it needs no
  # overlay pkgs to recompute the palette.
  eval-defaults-aerc-styleset =
    testNixOSCheck "defaults-aerc-styleset"
      (
        config:
        let
          aerc = config.home-manager.users.testuser.programs.aerc;
          g = aerc.stylesets.marchyo.global;
        in
        aerc.extraConfig.ui.styleset-name == "marchyo"
        && g."msglist_unread.fg" == g."title.fg"
        && g."msglist_unread.fg" == g."tab.selected.fg"
        && g."msglist_unread.fg" != g."completion_pill.bg"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.variant = "light";
        marchyo.defaults.email = "aerc";
      });

  # The other module-backed selections: ncspot (music), cmus (audio), neomutt
  # (email). Exercises the defaults.nix hasAttr guards (these install via their
  # Home-Manager modules, not environment.systemPackages).
  eval-defaults-tui-alt = testNixOS "defaults-tui-alt" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults = {
      musicPlayer = "ncspot";
      audioPlayer = "cmus";
      email = "neomutt";
    };
  });

  # Standard Emacs is the default editor: marchyo installs pkgs.emacs and
  # points $VISUAL/$EDITOR at emacsclient with plain-emacs fallbacks.
  eval-defaults-emacs-defaults =
    testNixOSCheck "defaults-emacs-defaults"
      (
        config:
        config.environment.sessionVariables.VISUAL == "emacsclient -c -a emacs"
        && config.environment.sessionVariables.EDITOR == "emacsclient -t -a 'emacs -nw'"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        # editor/terminalEditor left at their "emacs" defaults.
      });

  # Mixed case: emacs GUI editor + neovim terminal editor resolve independently.
  eval-defaults-emacs-mixed =
    testNixOSCheck "defaults-emacs-mixed"
      (
        config:
        config.environment.sessionVariables.VISUAL == "emacsclient -c -a emacs"
        && config.environment.sessionVariables.EDITOR == "nvim"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.defaults = {
          editor = "emacs";
          terminalEditor = "neovim";
        };
      });
}
