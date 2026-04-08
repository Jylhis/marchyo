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
    };
  };
}
