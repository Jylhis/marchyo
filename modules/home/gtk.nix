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
in
{
  config = lib.mkIf desktopEnabled {
    gtk = {
      gtk4.theme = lib.mkDefault config.gtk.theme;
      # marchyo owns the dark preference outright (no Stylix gtk target).
      # Adwaita is dual-variant; this picks its half.
      colorScheme = lib.mkDefault colorScheme;
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

    # HM's gtk3 module and this one both write this key (marchyo is the only
    # other writer since the stylix retirement); under the light variant their
    # values diverge, so mkForce resolves it in marchyo's favor. The dropped HM
    # value is cosmetic (only drives Epiphany's dark-mode request, which
    # prefer-light serves).
    dconf.settings."org/gnome/desktop/interface"."color-scheme" = lib.mkForce "prefer-${colorScheme}";
  };
}
