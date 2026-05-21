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
          "vlc"
          "amberol"
        ]
      );
      default = "mpv";
      example = "vlc";
      description = ''
        Default audio player for local files. Installed automatically when
        desktop is enabled and registered as the system default for audio
        MIME types. Set to null to skip audio player management.
      '';
    };

    musicPlayer = mkOption {
      type = types.nullOr (types.enum [ "spotify" ]);
      default = "spotify";
      example = "spotify";
      description = ''
        Default music streaming player. Installed automatically when desktop
        is enabled. Set to null to skip music player management.
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
          "gmail"
          "thunderbird"
          "outlook"
        ]
      );
      default = "gmail";
      example = "thunderbird";
      description = ''
        Default email client. "gmail" and "outlook" are web apps opened in
        the browser (no package installed). "thunderbird" installs the native
        client. Set to null to skip email management.
      '';
    };
  };
}
