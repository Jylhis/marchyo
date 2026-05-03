{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = (osConfig.marchyo or { }).desktop.enable or false;
  home = config.home.homeDirectory;
  gtkCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/gtk.css";
in
{
  config = lib.mkMerge [
    {
      gtk.gtk4.theme = lib.mkDefault config.gtk.theme;
    }
    (lib.mkIf desktopEnabled {
      gtk = {
        iconTheme = {
          package = pkgs.adwaita-icon-theme;
          name = "Adwaita";
        };
        gtk3 = {
          extraCss = gtkCss;
          bookmarks = [
            "file://${config.xdg.userDirs.documents}"
            "file://${config.xdg.userDirs.download}"
            "file://${config.xdg.userDirs.music}"
            "file://${config.xdg.userDirs.pictures}"
            "file://${config.xdg.userDirs.videos}"
            "file://${home}/Developer"
          ];
        };
        gtk4.extraCss = gtkCss;
      };
    })
  ];
}
