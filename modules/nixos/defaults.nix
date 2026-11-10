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

  editorPackages = {
    inherit (pkgs) emacs;
    inherit (pkgs) vscode;
    inherit (pkgs) vscodium;
    zed = pkgs.zed-editor;
  };

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

  # musicPlayer install paths live outside this map: the TUI client
  # spotify-player installs via its Home-Manager module
  # (modules/home/spotify-player.nix), and the Spotify GUI installs
  # unconditionally via modules/nixos/media.nix (x86_64-only).

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

  # email install paths live outside this map: aerc installs via its
  # Home-Manager module (modules/home/aerc.nix); gmail/outlook are
  # web apps registered by modules/home/webapps.nix (no package).

  defaultPackages =
    lib.optional (d.browser != null) browserPackages.${d.browser}
    ++ lib.optional (
      d.editor != null && builtins.hasAttr d.editor editorPackages
    ) editorPackages.${d.editor}
    ++ lib.optional (
      d.terminalEditor != null && builtins.hasAttr d.terminalEditor terminalEditorPackages
    ) terminalEditorPackages.${d.terminalEditor}
    ++ lib.optional (d.videoPlayer != null) videoPlayerPackages.${d.videoPlayer}
    ++ lib.optional (
      d.audioPlayer != null && builtins.hasAttr d.audioPlayer audioPlayerPackages
    ) audioPlayerPackages.${d.audioPlayer}
    ++ lib.optional (d.fileManager != null) fileManagerPackages.${d.fileManager}
    ++ lib.optional (d.terminalFileManager != null) terminalFileManagerPackages.${d.terminalFileManager}
    ++ lib.optional (d.imageEditor != null) imageEditorPackages.${d.imageEditor};
in
{
  config = lib.mkIf cfg.desktop.enable (
    lib.mkMerge [
      # google-chrome is x86_64-only on Linux, so non-x86_64 needs a browser
      # fallback. Music players install elsewhere (TUI clients via their
      # Home-Manager modules; the Spotify GUI via modules/nixos/media.nix,
      # x86_64-only), so only the browser needs a default here.
      (lib.mkIf (!pkgs.stdenv.hostPlatform.isx86_64) {
        marchyo.defaults.browser = lib.mkDefault "chromium";
      })
      {
        environment.systemPackages = defaultPackages;

        environment.sessionVariables =
          lib.optionalAttrs (d.editor != null && builtins.hasAttr d.editor editorVisualCommands) {
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
