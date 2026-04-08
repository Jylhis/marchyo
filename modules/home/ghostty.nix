{
  lib,
  ...
}:
let
  inherit (lib) mkDefault;
in
{
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      window-padding-x = 14;
      window-padding-y = 14;
      window-decoration = false;
      cursor-style = "block";
      cursor-style-blink = false;
      confirm-close-surface = false;
      unfocused-split-opacity = mkDefault 0.7;
      gtk-single-instance = true;
      keybind = [
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
    };
  };
}
