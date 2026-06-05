{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
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

  # Jotain is externally managed (no package installed by marchyo).
  eval-defaults-jotain = testNixOS "defaults-jotain" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults = {
      editor = "jotain";
      terminalEditor = "jotain";
    };
  });
}
