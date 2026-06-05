# XDG MIME type associations for default applications
{
  config,
  lib,
  osConfig ? { },
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };

  browserDesktopFiles = {
    brave = "brave-browser.desktop";
    google-chrome = "google-chrome.desktop";
    firefox = "firefox.desktop";
    chromium = "chromium-browser.desktop";
  };

  editorDesktopFiles = {
    emacs = "emacsclient.desktop";
    jotain = "emacsclient.desktop";
    vscode = "code.desktop";
    vscodium = "codium.desktop";
    zed = "dev.zed.Zed.desktop";
  };

  videoPlayerDesktopFiles = {
    mpv = "mpv.desktop";
    vlc = "vlc.desktop";
    celluloid = "io.github.celluloid_player.Celluloid.desktop";
  };

  audioPlayerDesktopFiles = {
    mpv = "mpv.desktop";
    vlc = "vlc.desktop";
    amberol = "io.bassi.Amberol.desktop";
  };

  fileManagerDesktopFiles = {
    nautilus = "org.gnome.Nautilus.desktop";
    thunar = "thunar.desktop";
  };

  # TUI mail clients ship a Terminal=true desktop file with a mailto handler;
  # web/null clients get none and fall back to the browser.
  emailDesktopFiles = {
    aerc = "aerc.desktop";
    neomutt = "neomutt.desktop";
  };

  browser = defaults.browser or null;
  editor = defaults.editor or null;
  videoPlayer = defaults.videoPlayer or null;
  audioPlayer = defaults.audioPlayer or null;
  fileManager = defaults.fileManager or null;
  email = defaults.email or null;

  browserDesktop = lib.optional (browser != null) browserDesktopFiles.${browser};
  editorDesktop = lib.optional (
    editor != null && builtins.hasAttr editor editorDesktopFiles
  ) editorDesktopFiles.${editor};
  # TUI players (e.g. cmus) have no single-file MIME handler; hasAttr-guard so
  # selecting one simply registers no association instead of failing eval.
  videoDesktop = lib.optional (
    videoPlayer != null && builtins.hasAttr videoPlayer videoPlayerDesktopFiles
  ) videoPlayerDesktopFiles.${videoPlayer};
  audioDesktop = lib.optional (
    audioPlayer != null && builtins.hasAttr audioPlayer audioPlayerDesktopFiles
  ) audioPlayerDesktopFiles.${audioPlayer};
  fileManagerDesktop = lib.optional (fileManager != null) fileManagerDesktopFiles.${fileManager};

  browserMimeTypes = lib.optionalAttrs (browserDesktop != [ ]) {
    "x-scheme-handler/http" = browserDesktop;
    "x-scheme-handler/https" = browserDesktop;
    "x-scheme-handler/ftp" = browserDesktop;
    "text/html" = browserDesktop;
    "application/xhtml+xml" = browserDesktop;
  };

  editorMimeTypes = lib.optionalAttrs (editorDesktop != [ ]) {
    "text/plain" = editorDesktop;
  };

  videoMimeTypes = lib.optionalAttrs (videoDesktop != [ ]) {
    "video/mp4" = videoDesktop;
    "video/webm" = videoDesktop;
    "video/x-matroska" = videoDesktop;
    "video/quicktime" = videoDesktop;
    "video/x-msvideo" = videoDesktop;
    "video/mpeg" = videoDesktop;
  };

  audioMimeTypes = lib.optionalAttrs (audioDesktop != [ ]) {
    "audio/mpeg" = audioDesktop;
    "audio/flac" = audioDesktop;
    "audio/ogg" = audioDesktop;
    "audio/x-wav" = audioDesktop;
    "audio/mp4" = audioDesktop;
  };

  fileManagerMimeTypes = lib.optionalAttrs (fileManagerDesktop != [ ]) {
    "inode/directory" = fileManagerDesktop;
  };

  # mailto: aerc/neomutt get their own desktop file; gmail/outlook (and any
  # client without a desktop file) fall back to opening in the browser.
  emailMimeTypes =
    if email == null then
      { }
    else if builtins.hasAttr email emailDesktopFiles then
      { "x-scheme-handler/mailto" = [ emailDesktopFiles.${email} ]; }
    else if browserDesktop != [ ] then
      { "x-scheme-handler/mailto" = browserDesktop; }
    else
      { };
in
{
  config = {
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
      extraConfig = {
        DEVELOPER = "${config.home.homeDirectory}/Developer";
      };
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # Images — Loupe is always the viewer; imageEditor is install-only
        "image/png" = [ "org.gnome.Loupe.desktop" ];
        "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
        "image/gif" = [ "org.gnome.Loupe.desktop" ];
        "image/webp" = [ "org.gnome.Loupe.desktop" ];
        "image/svg+xml" = [ "org.gnome.Loupe.desktop" ];
        "image/bmp" = [ "org.gnome.Loupe.desktop" ];
        "image/tiff" = [ "org.gnome.Loupe.desktop" ];

        # Documents
        "application/pdf" = [ "org.gnome.Papers.desktop" ];

        # Archives are handled from the terminal (ouch / yazi); no GUI handler.
      }
      // fileManagerMimeTypes
      // videoMimeTypes
      // audioMimeTypes
      // browserMimeTypes
      // editorMimeTypes
      // emailMimeTypes;
    };
  };
}
