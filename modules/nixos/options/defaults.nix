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
        "jotain" (the default, Jylhis's Emacs config) installs via its
        services.jotain Home-Manager module; marchyo sets $VISUAL to its
        jotain-visual wrapper. Switch to "emacs", "vscode", etc. to use a
        standard editor instead.
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
        "jotain" (the default, Jylhis's Emacs config) installs via its
        services.jotain Home-Manager module; marchyo sets $EDITOR to its
        jotain-editor wrapper. Switch to "emacs", "neovim", etc. to use a
        standard editor instead.
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
        Default audio player for local files. "mpv" (the default) opens audio
        files headlessly and is registered as the system default for audio
        MIME types. "cmus" is a TUI library player with no single-file MIME
        handler: selecting it installs cmus via its Home-Manager module but
        leaves audio files without a registered opener (launch it manually).
        Set to null to skip audio player management.
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
        Default music client bound to the Hyprland Super+M keybind. Defaults
        to "spotify-player", a TUI Spotify client launched in a floating
        terminal; "ncspot" is an alternative TUI client. Both install via
        their Home-Manager modules when selected. "spotify" is the GUI app,
        always installed on x86_64 (see modules/nixos/media.nix); selecting it
        here only binds Super+M to it. Set to null to skip music player
        management.
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
          "outlook"
        ]
      );
      default = "aerc";
      example = "neomutt";
      description = ''
        Default email client. Defaults to "aerc", a TUI mail client (mailto
        links open it in a terminal); "neomutt" is an alternative TUI client.
        Both install via their Home-Manager modules and require account
        configuration before use. "gmail" and "outlook" are web apps opened
        in the browser (no package installed). Set to null to skip email
        management.
      '';
    };
  };
}
