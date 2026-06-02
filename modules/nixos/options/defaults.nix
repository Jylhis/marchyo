{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.defaults = {
    browser = mkOption {
      type = types.nullOr (
        types.enum [
          "brave"
          "google-chrome"
          "firefox"
          "chromium"
        ]
      );
      default = "google-chrome";
      example = "firefox";
      description = ''
        Default web browser. Installed automatically when desktop is enabled
        and registered as the system default for HTTP/HTTPS links.
        Set to null to skip browser management.
      '';
    };

    editor = mkOption {
      type = types.nullOr (
        types.enum [
          "emacs"
          "jotain"
          "vscode"
          "vscodium"
          "zed"
        ]
      );
      default = "jotain";
      example = "vscode";
      description = ''
        Default graphical text editor ($VISUAL). Installed automatically when
        desktop is enabled and registered as the system default for plain text
        files. Set to null to skip editor management.
        "jotain" is externally managed (like "gmail"/"outlook" for email):
        package installation and VISUAL are handled by programs.jotain.
      '';
    };

    terminalEditor = mkOption {
      type = types.nullOr (
        types.enum [
          "emacs"
          "jotain"
          "neovim"
          "helix"
          "nano"
        ]
      );
      default = "jotain";
      example = "neovim";
      description = ''
        Default terminal text editor ($EDITOR). Installed automatically when
        desktop is enabled. Set to null to skip terminal editor management.
        "jotain" is externally managed (like "gmail"/"outlook" for email):
        package installation and EDITOR are handled by programs.jotain.
      '';
    };

    videoPlayer = mkOption {
      type = types.nullOr (
        types.enum [
          "mpv"
          "vlc"
          "celluloid"
        ]
      );
      default = "mpv";
      example = "vlc";
      description = ''
        Default video player. Installed automatically when desktop is enabled
        and registered as the system default for video MIME types.
        Set to null to skip video player management.
      '';
    };

    audioPlayer = mkOption {
      type = types.nullOr (
        types.enum [
          "mpv"
          "cmus"
          "vlc"
          "amberol"
        ]
      );
      default = "mpv";
      example = "cmus";
      description = ''
        Default audio player for local files. Installed automatically when
        desktop is enabled and registered as the system default for audio
        MIME types. "mpv" plays files headlessly in a terminal and remains
        the file-open default; "cmus" is a TUI library player launched
        manually (no single-file MIME handler). Set to null to skip audio
        player management.
      '';
    };

    musicPlayer = mkOption {
      type = types.nullOr (
        types.enum [
          "spotify-player"
          "ncspot"
          "spotify"
        ]
      );
      default = "spotify-player";
      example = "ncspot";
      description = ''
        Default music streaming player. Defaults to "spotify-player", a TUI
        Spotify client launched in a floating terminal. "ncspot" is an
        alternative TUI client; "spotify" installs the GUI app (x86_64-only).
        Installed automatically when desktop is enabled. Set to null to skip
        music player management.
      '';
    };

    fileManager = mkOption {
      type = types.nullOr (
        types.enum [
          "nautilus"
          "thunar"
        ]
      );
      default = "nautilus";
      example = "thunar";
      description = ''
        Default graphical file manager. Installed automatically when desktop
        is enabled and registered as the system default for directory MIME
        types. Set to null to skip file manager management.
      '';
    };

    terminalFileManager = mkOption {
      type = types.nullOr (
        types.enum [
          "yazi"
          "ranger"
          "lf"
        ]
      );
      default = "yazi";
      example = "ranger";
      description = ''
        Default terminal file manager. Installed automatically when desktop
        is enabled. Set to null to skip terminal file manager management.
      '';
    };

    imageEditor = mkOption {
      type = types.nullOr (
        types.enum [
          "pinta"
          "gimp"
          "krita"
        ]
      );
      default = "pinta";
      example = "gimp";
      description = ''
        Default image editor. Installed automatically when desktop is enabled.
        Set to null to skip image editor management.
      '';
    };

    email = mkOption {
      type = types.nullOr (
        types.enum [
          "aerc"
          "neomutt"
          "gmail"
          "thunderbird"
          "outlook"
        ]
      );
      default = "aerc";
      example = "thunderbird";
      description = ''
        Default email client. Defaults to "aerc", a TUI mail client (mailto
        links open it in a terminal). "neomutt" is an alternative TUI client.
        Both require account configuration before use. "gmail" and "outlook"
        are web apps opened in the browser (no package installed).
        "thunderbird" installs the native GUI client. Set to null to skip
        email management.
      '';
    };
  };
}
