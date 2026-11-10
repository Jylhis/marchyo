# marchyo.defaults.*: every value evaluates, and the resolved editor
# variables, the aerc styleset and excludePackages behave. The values each
# reference system sets are in refConfig at the bottom.
_: {
  refs = {
    desktop-tweaks = {
      eval-defaults-browser = cfg: cfg.marchyo.defaults.browser == "google-chrome";

      # TUI defaults: spotify-player (music) and aerc (email) install via their
      # Home-Manager modules, not environment.systemPackages, which exercises the
      # defaults.nix hasAttr guards.
      eval-defaults-tui =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        hm.programs.aerc.enable && hm.programs.spotify-player.enable;
    };

    # editor/terminalEditor at their "emacs" defaults.
    desktop = {
      eval-defaults-editor =
        cfg: cfg.marchyo.defaults.editor == "emacs" && cfg.marchyo.defaults.terminalEditor == "emacs";

      # Standard Emacs is the default editor: marchyo installs pkgs.emacs and
      # points $VISUAL/$EDITOR at emacsclient with plain-emacs fallbacks.
      eval-defaults-emacs-defaults =
        config:
        config.environment.sessionVariables.VISUAL == "emacsclient -c -a emacs"
        && config.environment.sessionVariables.EDITOR == "emacsclient -t -a 'emacs -nw'";
    };

    # All defaults set to null = marchyo manages nothing.
    desktop-off.eval-defaults-null = cfg: cfg.marchyo.defaults.browser == null;

    desktop-tweaks-3.eval-defaults-all = cfg: cfg.marchyo.defaults.musicPlayer == "spotify";

    # aerc styleset regression: marchyo hand-rolls its own styleset (the former
    # Stylix aerc target used base07 (= surface-raised, near-white in Sheet) as a
    # *foreground*, giving white-on-white unread subjects / title / header in the
    # light variant). Assert (in the light variant) that the styleset is named
    # "marchyo", that unread subjects / title / selected-tab share the heading
    # ink, and — the crux — that that ink is NOT the near-white surface-raised
    # (which the styleset reuses only as completion_pill.bg, a background).
    # Kept config-relative so it needs no overlay pkgs to recompute the palette.
    desktop-light.eval-defaults-aerc-styleset =
      config:
      let
        aerc = config.home-manager.users.testuser.programs.aerc;
        g = aerc.stylesets.marchyo.global;
      in
      aerc.extraConfig.ui.styleset-name == "marchyo"
      && g."msglist_unread.fg" == g."title.fg"
      && g."msglist_unread.fg" == g."tab.selected.fg"
      && g."msglist_unread.fg" != g."completion_pill.bg";

    desktop-tweaks-2 = {
      # excludePackages subtracts from marchyo's default bundles: eza (always in
      # shellTools) drops out while ripgrep (also shellTools, not excluded) stays.
      # The config module takes `pkgs` so the excluded value is pointer-identical
      # to the one packages.nix installs; the predicate matches by pname so it
      # does not depend on cross-instance derivation equality.
      eval-defaults-exclude-packages =
        config:
        let
          names = map (p: p.pname or "") config.environment.systemPackages;
        in
        !(builtins.elem "eza" names) && builtins.elem "ripgrep" names;

      # Mixed case: emacs GUI editor + neovim terminal editor resolve independently.
      eval-defaults-emacs-mixed =
        config:
        config.environment.sessionVariables.VISUAL == "emacsclient -c -a emacs"
        && config.environment.sessionVariables.EDITOR == "nvim";
    };
  };

  refConfig = {
    desktop-tweaks.marchyo.defaults = {
      browser = "google-chrome";
      musicPlayer = "spotify-player";
      email = "aerc";
    };
    desktop-tweaks-2 =
      { pkgs, ... }:
      {
        marchyo.defaults = {
          editor = "emacs";
          terminalEditor = "neovim";
          excludePackages = [ pkgs.eza ];
        };
      };
    desktop-tweaks-3.marchyo.defaults = {
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
    desktop-off.marchyo.defaults = {
      browser = null;
      editor = null;
      terminalEditor = null;
      videoPlayer = null;
      audioPlayer = null;
      musicPlayer = null;
      fileManager = null;
      terminalFileManager = null;
      imageEditor = null;
      email = null;
    };
    desktop-light.marchyo.defaults.email = "aerc";
  };
}
