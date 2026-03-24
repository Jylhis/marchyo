{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = (osConfig.marchyo or { }).desktop.enable or false;
in
{
  config = lib.mkIf desktopEnabled {
    gtk = {
      gtk4.theme = null;
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };
    };
  };
}
