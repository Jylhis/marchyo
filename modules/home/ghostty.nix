{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    optionalAttrs
    ;
  inherit (pkgs.stdenv) isDarwin;

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
in
{
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
      window-padding-x = 14;
      window-padding-y = 14;
      cursor-style = "block";
      cursor-style-blink = false;
      confirm-close-surface = false;
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
}
