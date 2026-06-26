{ helpers, ... }:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    testNixOSFails
    withTestUser
    ;
in
{
  eval-defaults-browser = testNixOS "defaults-browser" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = "google-chrome";
  });

  # Both selectors must agree on the Emacs flavour: "emacs" alone would leave
  # terminalEditor at its "jotain" default, which the mix assertion rejects.
  eval-defaults-editor = testNixOS "defaults-editor" (withTestUser {
    marchyo.desktop.enable = true;
    # terminalEditor defaults to "jotain"; "emacs" + "jotain" trips the
    # cannot-mix assertion, so pin both to "emacs".
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

  # Jotain (Jylhis's Emacs config) is the default editor: marchyo installs no
  # package directly (its services.jotain Home-Manager module does), but owns
  # $EDITOR/$VISUAL, pointing them at jotain's on-PATH wrapper scripts.
  eval-defaults-jotain =
    testNixOSCheck "defaults-jotain"
      (
        config:
        config.environment.sessionVariables.EDITOR == "jotain-editor"
        && config.environment.sessionVariables.VISUAL == "jotain-visual"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.defaults = {
          editor = "jotain";
          terminalEditor = "jotain";
        };
      });

  # Mixed case: jotain GUI editor + neovim terminal editor resolve independently.
  eval-defaults-jotain-mixed =
    testNixOSCheck "defaults-jotain-mixed"
      (
        config:
        config.environment.sessionVariables.VISUAL == "jotain-visual"
        && config.environment.sessionVariables.EDITOR == "nvim"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.defaults = {
          editor = "jotain";
          terminalEditor = "neovim";
        };
      });

  # jotain + the marchyo.emacs daemon both bind the default Emacs socket — the
  # default editors leave jotain selected, so enabling marchyo.emacs must fail.
  eval-defaults-jotain-emacs-daemon-conflict =
    testNixOSFails "defaults-jotain-emacs-daemon-conflict" "marchyo.emacs.enable conflicts"
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.emacs.enable = true;
        # editor/terminalEditor left at their "jotain" defaults.
      });

  # jotain's emacs/emacsclient shadow pkgs.emacs on PATH, so mixing the two
  # editor selections must fail rather than silently run jotain on both.
  eval-defaults-jotain-emacs-mix =
    testNixOSFails "defaults-jotain-emacs-mix" "cannot mix"
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.defaults = {
          editor = "emacs";
          terminalEditor = "jotain";
        };
      });
}
