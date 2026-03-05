# XDG MIME type associations for default applications
{
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

  browser = defaults.browser or null;
  editor = defaults.editor or null;
  videoPlayer = defaults.videoPlayer or null;
  audioPlayer = defaults.audioPlayer or null;
  fileManager = defaults.fileManager or null;
  email = defaults.email or null;

  browserDesktop = lib.optional (browser != null) browserDesktopFiles.${browser};
  editorDesktop = lib.optional (editor != null) editorDesktopFiles.${editor};
  videoDesktop = lib.optional (videoPlayer != null) videoPlayerDesktopFiles.${videoPlayer};
  audioDesktop = lib.optional (audioPlayer != null) audioPlayerDesktopFiles.${audioPlayer};
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

  # mailto: thunderbird gets its own desktop file; gmail/outlook open in browser
  emailMimeTypes =
    if email == null then
      { }
    else if email == "thunderbird" then
      { "x-scheme-handler/mailto" = [ "thunderbird.desktop" ]; }
    else if browserDesktop != [ ] then
      { "x-scheme-handler/mailto" = browserDesktop; }
    else
      { };
in
{
  config = {
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

        # Archives
        "application/zip" = [ "org.gnome.FileRoller.desktop" ];
        "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
        "application/gzip" = [ "org.gnome.FileRoller.desktop" ];
        "application/x-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
        "application/x-bzip-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
        "application/x-xz-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
        "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
        "application/x-rar" = [ "org.gnome.FileRoller.desktop" ];
        "application/vnd.rar" = [ "org.gnome.FileRoller.desktop" ];
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
