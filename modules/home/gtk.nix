{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  home = config.home.homeDirectory;
in
{
  config = lib.mkIf desktopEnabled {
    gtk = {
      gtk4.theme = lib.mkDefault config.gtk.theme;
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };
      gtk3 = {
        bookmarks = [
          "file://${config.xdg.userDirs.documents}"
          "file://${config.xdg.userDirs.download}"
          "file://${config.xdg.userDirs.music}"
          "file://${config.xdg.userDirs.pictures}"
          "file://${config.xdg.userDirs.videos}"
          "file://${home}/Developer"
        ];
      };
    };
  };
}
