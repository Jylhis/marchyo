{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib)
    mkAfter
    mkDefault
    mkIf
    optionalAttrs
    ;
  inherit (pkgs.stdenv) isDarwin;

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  ghosttyTheme = if themeVariant == "dark" then "jylhis-roast" else "jylhis-paper";

  # Generate a Ghostty theme file from mkPalette so the paper ANSI 7/15
  # readability override is applied (see modules/generic/jylhis-palette.nix).
  mkGhosttyTheme =
    variant:
    let
      palette = import ../generic/jylhis-palette.nix {
        inherit pkgs lib;
        inherit variant;
      };
      paletteLines = lib.concatStringsSep "\n" (
        lib.imap0 (i: hex: "palette = ${toString i}=#${hex}") palette.ansi16
      );
    in
    ''
      ${paletteLines}

      background  = ${palette.hex.bg}
      foreground  = ${palette.hex.text}
      cursor-color = ${palette.hex.cursor}
      cursor-text  = ${palette.hex.bg}
      selection-background = ${palette.hex."selection-bg"}
      selection-foreground = ${palette.hex.text}
    '';

  linuxKeybinds = [
    "alt+1=goto_tab:1"
    "alt+2=goto_tab:2"
    "alt+3=goto_tab:3"
    "alt+4=goto_tab:4"
    "alt+5=goto_tab:5"
    "alt+6=goto_tab:6"
    "alt+7=goto_tab:7"
    "alt+8=goto_tab:8"
    "alt+9=last_tab"
  ];

  # Aerospace owns alt-* on macOS (workspace switching, focus movement). Unbind
  # ghostty's alt-arrow word-jump bindings so those keys pass through to the
  # shell / tmux / Aerospace. cmd never escapes to the TTY, so cmd+N is a safe
  # choice for tab switching.
  darwinKeybinds = [
    "alt+left=unbind"
    "alt+right=unbind"
    "alt+up=unbind"
    "alt+down=unbind"

    "cmd+1=goto_tab:1"
    "cmd+2=goto_tab:2"
    "cmd+3=goto_tab:3"
    "cmd+4=goto_tab:4"
    "cmd+5=goto_tab:5"
    "cmd+6=goto_tab:6"
    "cmd+7=goto_tab:7"
    "cmd+8=goto_tab:8"
    "cmd+9=goto_tab:9"

    "f11=toggle_fullscreen"
  ];

  # Set the tab/window title to the last two path segments (e.g.
  # "jylhis/marchyo") when idle, and "<short-path>: <command>" while a command
  # runs. Ghostty's own "title" shell-integration feature is disabled below
  # (it hardcodes the full `\w` path); this replaces it. Registered via the
  # precmd/preexec arrays that ghostty's bundled bash-preexec exposes in bash
  # and that zsh provides natively, so it coexists with starship's hooks.
  titleHooks = ''
    __marchyo_short_pwd() {
      local p=''${PWD/#$HOME/\~}
      local base=''${p##*/}
      local parent=''${p%/*}
      if [ "$p" = "$base" ] || [ -z "$parent" ] || [ "$parent" = "$p" ]; then
        printf '%s' "$p"
      else
        printf '%s/%s' "''${parent##*/}" "$base"
      fi
    }
    __marchyo_title_precmd() { printf '\033]2;%s\007' "$(__marchyo_short_pwd)"; }
    __marchyo_title_preexec() {
      local cmd=''${1//[[:cntrl:]]/}
      printf '\033]2;%s: %s\007' "$(__marchyo_short_pwd)" "$cmd"
    }
    precmd_functions+=(__marchyo_title_precmd)
    preexec_functions+=(__marchyo_title_preexec)
  '';
in
{
  # Install marchyo-derived Ghostty themes (both variants, active one set
  # in programs.ghostty.settings.theme).
  xdg.configFile."ghostty/themes/jylhis-roast".text = mkGhosttyTheme "dark";
  xdg.configFile."ghostty/themes/jylhis-paper".text = mkGhosttyTheme "light";

  programs.ghostty = {
    enable = true;

    # pkgs.ghostty is the GTK/Linux build and is marked broken on Darwin;
    # ghostty-bin repackages the official macOS .dmg.
    package = mkIf isDarwin pkgs.ghostty-bin;

    # ghostty-bin's .app bundle does not ship the bat syntax file the HM module
    # expects, so disable it on darwin to avoid an eval-time path that doesn't exist.
    installBatSyntax = mkIf isDarwin false;

    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;

    settings = {
      theme = ghosttyTheme;
      font-family = "JetBrainsMono Nerd Font";
      window-padding-x = 8;
      window-padding-y = 8;
      cursor-style = "block";
      cursor-style-blink = false;
      confirm-close-surface = false;
      # Disable ghostty's built-in full-path title feature; titleHooks below
      # sets a shorter last-two-segments title instead. Other integration
      # features (cursor, sudo, ssh-*) stay enabled.
      shell-integration-features = "no-title";
      unfocused-split-opacity = mkDefault 0.7;
      keybind = if isDarwin then darwinKeybinds else linuxKeybinds;
    }
    // optionalAttrs (!isDarwin) {
      window-decoration = false;
      gtk-single-instance = true;
    }
    // optionalAttrs isDarwin {
      # Left Option = Alt for terminal bindings; right Option keeps OS
      # dead-key compose so accented characters still work.
      macos-option-as-alt = "left";
      window-save-state = "never";
    };
  };

  # Register the short-path title hook in each active shell. mkAfter places it
  # after ghostty's own integration snippet so the precmd/preexec arrays exist.
  programs.bash.initExtra = mkIf config.programs.bash.enable (mkAfter titleHooks);
  programs.zsh.initContent = mkIf config.programs.zsh.enable (mkAfter titleHooks);
}
