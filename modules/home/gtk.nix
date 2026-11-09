{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  home = config.home.homeDirectory;
  colorScheme =
    if ((osConfig.marchyo or { }).theme.variant or "dark") == "dark" then "dark" else "light";
  runtimeTheme =
    ((osConfig.marchyo or { }).theme.enable or true) && ((osConfig.marchyo or { }).cli.enable or false);
in
{
  config = lib.mkIf desktopEnabled {
    gtk = {
      gtk4.theme = lib.mkDefault config.gtk.theme;
      colorScheme = lib.mkDefault (if runtimeTheme then null else colorScheme);
      gtk3.colorScheme = lib.mkIf runtimeTheme (lib.mkForce null);
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

    dconf.settings."org/gnome/desktop/interface"."color-scheme" = lib.mkIf (!runtimeTheme) (
      lib.mkForce "prefer-${colorScheme}"
    );
  };
}
