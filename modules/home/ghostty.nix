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
  # precmd/preexec arrays: zsh provides them natively; bash needs bash-preexec,
  # loaded explicitly for bash below (see bashTitleHooks). Sharing these arrays
  # is what lets the title hooks coexist with starship's own precmd hook.
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

  # Bash-only prelude. Modern Ghostty (bash >= 4.4) drives its shell integration
  # through PS0 and does NOT source bash-preexec, so precmd_functions/preexec_functions
  # would never be iterated. Their mere presence also makes starship register
  # starship_precmd into precmd_functions instead of PROMPT_COMMAND, so the starship
  # prompt silently stops rendering. Load bash-preexec first so both fire.
  bashTitleHooks = ''
    if [ -z "''${bash_preexec_imported:-}''${__bp_imported:-}" ]; then
      source ${pkgs.bash-preexec}/share/bash/bash-preexec.sh
    fi
  ''
  + titleHooks;
in
{
  # Install the upstream Jylhis Ghostty themes (both variants, active one set
  # in programs.ghostty.settings.theme). Done here rather than through the
  # upstream HM module (disabled in modules/home/jylhis-theme.nix) so the
  # themes are also installed on darwin, where that module is Linux-gated.
  xdg.configFile."ghostty/themes/jylhis-roast".source =
    "${pkgs.jylhis-design-src}/platforms/ghostty/jylhis-roast";
  xdg.configFile."ghostty/themes/jylhis-paper".source =
    "${pkgs.jylhis-design-src}/platforms/ghostty/jylhis-paper";

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
      # sets a shorter last-two-segments title instead. ssh-env and
      # ssh-terminfo are OPT-IN upstream (disabled by default): ssh-terminfo
      # installs xterm-ghostty on the remote host via infocmp/tic on first
      # connect, and ssh-env falls back to TERM=xterm-256color when that isn't
      # possible — without them, remote TUI apps break on unknown terminfo.
      shell-integration-features = "no-title,ssh-env,ssh-terminfo";
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
  # after ghostty's own integration snippet. bash additionally loads bash-preexec
  # (see bashTitleHooks); zsh drives the precmd/preexec arrays natively.
  programs.bash.initExtra = mkIf config.programs.bash.enable (mkAfter bashTitleHooks);
  programs.zsh.initContent = mkIf config.programs.zsh.enable (mkAfter titleHooks);
}
