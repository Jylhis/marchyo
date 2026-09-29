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
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  ghosttyTheme = if themeVariant == "dark" then "jylhis-dark" else "jylhis-light";

  fontScale = (osConfig.marchyo or { }).theme.fontScale or 1.0;
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };

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

  # cmd never escapes to the TTY, so cmd+N is a safe choice for tab switching
  # on macOS.
  darwinKeybinds = [
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

  # Set the title to the last two path segments when idle, "<short-path>: <command>"
  # while a command runs. Replaces Ghostty's own title feature (disabled below, it
  # hardcodes the full `\w` path). Uses the precmd/preexec arrays so the hooks coexist
  # with starship's own precmd hook.
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

  # Modern Ghostty drives bash shell integration through PS0 and does NOT source
  # bash-preexec, so precmd_functions/preexec_functions never fire. Worse, their mere
  # presence makes starship register into precmd_functions instead of PROMPT_COMMAND,
  # silently stopping the prompt. Load bash-preexec first so both fire.
  bashTitleHooks = ''
    if [ -z "''${bash_preexec_imported:-}''${__bp_imported:-}" ]; then
      source ${pkgs.bash-preexec}/share/bash/bash-preexec.sh
    fi
  ''
  + titleHooks;
in
{
  # Install both Jylhis Ghostty themes here rather than via the upstream HM module
  # (disabled in modules/home/jylhis-theme.nix, Linux-gated) so darwin gets them too.
  # Path reference into the built jylhis-themes package, not an eval-time read, to stay
  # import-from-derivation-free.
  xdg.configFile."ghostty/themes/jylhis-dark".source =
    "${pkgs.jylhis-themes}/share/jylhis/ghostty/jylhis-dark";
  xdg.configFile."ghostty/themes/jylhis-light".source =
    "${pkgs.jylhis-themes}/share/jylhis/ghostty/jylhis-light";

  programs.ghostty = {
    enable = true;

    # pkgs.ghostty is the GTK/Linux build and is marked broken on Darwin;
    # ghostty-bin repackages the official macOS .dmg.
    package = mkIf isDarwin pkgs.ghostty-bin;

    # ghostty-bin's .app bundle does not ship the bat syntax file the HM module
    # expects, so disable it on darwin to avoid an eval-time path that doesn't exist.
    installBatSyntax = mkIf isDarwin false;

    enableBashIntegration = config.programs.bash.enable;

    settings = {
      theme = ghosttyTheme;
      font-family = "BlexMono Nerd Font";
      font-size = fs.round 12;
      window-padding-x = 8;
      window-padding-y = 8;
      cursor-style = "block";
      cursor-style-blink = false;
      confirm-close-surface = false;
      # no-title: titleHooks sets the shorter title instead. ssh-env / ssh-terminfo
      # are opt-in upstream and needed here: they install xterm-ghostty on the remote
      # (or fall back to TERM=xterm-256color), else remote TUIs break on unknown terminfo.
      shell-integration-features = "no-title,ssh-env,ssh-terminfo";
      unfocused-split-opacity = mkDefault 0.7;
      keybind = if isDarwin then darwinKeybinds else linuxKeybinds;
    }
    // optionalAttrs (!isDarwin) {
      window-decoration = false;
      gtk-single-instance = true;
      # Derive the tab-bar chrome from the terminal bg/fg, not the GTK theme: the
      # injected jylhis gtk.css overrides Adwaita-dark, so `window-theme = dark` left
      # the tab bar light. `ghostty` also tracks the runtime theme include
      # (modules/home/theme-runtime.nix) live.
      window-theme = "ghostty";
    }
    // optionalAttrs isDarwin {
      # Left Option = Alt for terminal bindings; right Option keeps OS
      # dead-key compose so accented characters still work.
      macos-option-as-alt = "left";
      window-save-state = "never";
    };
  };

  # mkAfter so this lands after ghostty's own integration snippet.
  programs.bash.initExtra = mkIf config.programs.bash.enable (mkAfter bashTitleHooks);
}
