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

  # jotain is itself a full Emacs distribution (it installs its own emacs +
  # emacsclient, plus a hiPrio `emacs` wrapper, into the user profile). It
  # therefore cannot share a home profile with another Emacs — neither the
  # marchyo.emacs daemon (same default socket) nor a plain "emacs" editor
  # selection (jotain's binaries shadow pkgs.emacs on PATH).
  jotainSelected = d.editor == "jotain" || d.terminalEditor == "jotain";
  emacsSelected = d.editor == "emacs" || d.terminalEditor == "emacs";

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

  # $VISUAL command for graphical editors.
  # jotain installs no package here (its Home-Manager module does, gated on the
  # marchyo.defaults selection — see modules/home/jotain.nix), but it ships a
  # `jotain-visual` wrapper on PATH that marchyo sets as $VISUAL.
  editorVisualCommands = {
    emacs = "emacsclient -c -a emacs";
    jotain = "jotain-visual";
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

  # $EDITOR command for terminal editors.
  # jotain ships a `jotain-editor` wrapper on PATH (installed by its
  # Home-Manager module, modules/home/jotain.nix) that marchyo sets as $EDITOR.
  terminalEditorCommands = {
    emacs = "emacsclient -t -a 'emacs -nw'";
    jotain = "jotain-editor";
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

  # musicPlayer install paths live outside this map: the TUI clients
  # (spotify-player, ncspot) install via their Home-Manager modules
  # (modules/home/{spotify-player,ncspot}.nix), and the Spotify GUI installs
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

  # email install paths live outside this map: aerc/neomutt install via their
  # Home-Manager modules (modules/home/{aerc,neomutt}.nix); gmail/outlook are
  # web apps opened in the browser (no package).
  # gmail → https://mail.google.com (TODO: register as PWA)
  # outlook → https://outlook.com (TODO: register as PWA)

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
        assertions = [
          # jotain runs an Emacs daemon on $XDG_RUNTIME_DIR/emacs/server, the
          # same default socket as the marchyo.emacs daemon — enabling both
          # races two daemons for one socket.
          {
            assertion = !(cfg.emacs.enable && jotainSelected);
            message = ''
              marchyo.emacs.enable conflicts with marchyo.defaults.editor/terminalEditor = "jotain":
              both run an Emacs daemon on $XDG_RUNTIME_DIR/emacs/server. Pick one — either disable
              marchyo.emacs.enable, or set the jotain selectors to a non-Emacs editor.
            '';
          }
          # jotain's emacs/emacsclient (hiPrio) shadow pkgs.emacs in the user
          # profile, so a mixed "jotain"+"emacs" selection would silently run
          # jotain on the "emacs" side.
          {
            assertion = !(jotainSelected && emacsSelected);
            message = ''
              marchyo.defaults cannot mix "jotain" and "emacs": jotain installs its own emacs/
              emacsclient (hiPrio) into the user profile, which shadows pkgs.emacs on PATH, so the
              "emacs" side would silently run jotain. Use "jotain" for both, or "emacs" for both.
            '';
          }
        ];

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
