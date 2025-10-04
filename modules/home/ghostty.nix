{
  programs.ghostty = {
    enable = true;
    settings = {
      # Window settings
      window-padding-x = 14;
      window-padding-y = 14;
      background-opacity = 0.95;
      window-decoration = "none";
      confirm-close-surface = false;
      resize-overlay = "never";
      cursor-style = "block";
      cursor-style-blink = false;
      shell-integration-features = "no-cursor";

      font-family = "CaskaydiaMono Nerd Font";
      font-style = "Regular";
      font-size = 9;

      #theme = "omarchy"; # FIXME
      keybind = [
        "ctrl+k=reset"
        "f11=toggle_fullscreen"
      ];
    };
  };
}
