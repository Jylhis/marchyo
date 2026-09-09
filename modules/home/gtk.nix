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
in
{
  config = lib.mkIf desktopEnabled {
    gtk = {
      gtk4.theme = lib.mkDefault config.gtk.theme;
      # marchyo disables Stylix's `gtk` target (modules/generic/theme.nix), so
      # nothing else sets the GTK3/4 dark preference in settings.ini. Adwaita
      # (the active theme) is dual-variant; this makes GTK3 apps load its dark
      # half and GTK4 ones advertise dark to libadwaita apps. dconf
      # `color-scheme = prefer-dark` from Stylix's `gnome` target covers GTK4
      # apps that read gsettings instead of settings.ini.
      colorScheme = lib.mkDefault (
        if ((osConfig.marchyo or { }).theme.variant or "dark") == "dark" then "dark" else "light"
      );
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
