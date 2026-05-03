# Default applications module
# Installs configured default apps and sets BROWSER/VISUAL/EDITOR env vars
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  d = cfg.defaults;

  browserPackages = {
    inherit (pkgs) brave;
    inherit (pkgs) google-chrome;
    inherit (pkgs) firefox;
    inherit (pkgs) chromium;
  };

  browserCommands = {
    brave = "brave";
    google-chrome = "google-chrome";
    firefox = "firefox";
    chromium = "chromium";
  };

  editorPackages = {
    inherit (pkgs) emacs;
    inherit (pkgs) vscode;
    inherit (pkgs) vscodium;
    zed = pkgs.zed-editor;
  };

  # $VISUAL command for graphical editors
  editorVisualCommands = {
    emacs = "emacsclient -c -a emacs";
    vscode = "code";
    vscodium = "codium";
    zed = "zed";
  };

  terminalEditorPackages = {
    inherit (pkgs) emacs; # shared with editor; NixOS deduplicates systemPackages
    inherit (pkgs) neovim;
    inherit (pkgs) helix;
    inherit (pkgs) nano;
  };

  # $EDITOR command for terminal editors
  terminalEditorCommands = {
    emacs = "emacsclient -t -a 'emacs -nw'";
    neovim = "nvim";
    helix = "hx";
    nano = "nano";
  };

  videoPlayerPackages = {
    inherit (pkgs) mpv;
    inherit (pkgs) vlc;
    inherit (pkgs) celluloid;
  };

  audioPlayerPackages = {
    inherit (pkgs) mpv; # shared with video when same; NixOS deduplicates
    inherit (pkgs) vlc;
    inherit (pkgs) amberol;
  };

  musicPlayerPackages = {
    inherit (pkgs) spotify;
  };

  fileManagerPackages = {
    inherit (pkgs) nautilus;
    inherit (pkgs.xfce) thunar;
  };

  terminalFileManagerPackages = {
    inherit (pkgs) yazi;
    inherit (pkgs) ranger;
    inherit (pkgs) lf;
  };

  imageEditorPackages = {
    inherit (pkgs) pinta;
    inherit (pkgs) gimp;
    inherit (pkgs) krita;
  };

  # email: URL-only apps (gmail, outlook) install no package
  # gmail → https://mail.google.com (TODO: register as PWA)
  # outlook → https://outlook.com (TODO: register as PWA)
  emailPackages = {
    inherit (pkgs) thunderbird;
  };

  defaultPackages =
    lib.optional (d.browser != null) browserPackages.${d.browser}
    ++ lib.optional (
      d.editor != null && builtins.hasAttr d.editor editorPackages
    ) editorPackages.${d.editor}
    ++ lib.optional (
      d.terminalEditor != null && builtins.hasAttr d.terminalEditor terminalEditorPackages
    ) terminalEditorPackages.${d.terminalEditor}
    ++ lib.optional (d.videoPlayer != null) videoPlayerPackages.${d.videoPlayer}
    ++ lib.optional (d.audioPlayer != null) audioPlayerPackages.${d.audioPlayer}
    ++ lib.optional (d.musicPlayer != null) musicPlayerPackages.${d.musicPlayer}
    ++ lib.optional (d.fileManager != null) fileManagerPackages.${d.fileManager}
    ++ lib.optional (d.terminalFileManager != null) terminalFileManagerPackages.${d.terminalFileManager}
    ++ lib.optional (d.imageEditor != null) imageEditorPackages.${d.imageEditor}
    ++ lib.optional (
      d.email != null && builtins.hasAttr d.email emailPackages
    ) emailPackages.${d.email};
in
{
  config = lib.mkIf cfg.desktop.enable (
    lib.mkMerge [
      # google-chrome and spotify are x86_64-only on Linux
      (lib.mkIf (!pkgs.stdenv.hostPlatform.isx86_64) {
        marchyo.defaults.browser = lib.mkDefault "chromium";
        marchyo.defaults.musicPlayer = lib.mkDefault null;
      })
      {
        environment.systemPackages = defaultPackages;

        environment.sessionVariables =
          lib.optionalAttrs (d.browser != null) { BROWSER = browserCommands.${d.browser}; }
          // lib.optionalAttrs (d.editor != null && builtins.hasAttr d.editor editorVisualCommands) {
            VISUAL = editorVisualCommands.${d.editor};
          }
          //
            lib.optionalAttrs
              (d.terminalEditor != null && builtins.hasAttr d.terminalEditor terminalEditorCommands)
              {
                EDITOR = terminalEditorCommands.${d.terminalEditor};
              };
      }
    ]
  );
}
