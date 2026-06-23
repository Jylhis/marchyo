{ helpers, ... }:
let
  inherit (helpers) testNixOS testNixOSCheck withTestUser;
in
{
  eval-defaults-browser = testNixOS "defaults-browser" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = "google-chrome";
  });

  eval-defaults-editor = testNixOS "defaults-editor" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.editor = "emacs";
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
}
