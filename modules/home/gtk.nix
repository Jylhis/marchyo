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
      # marchyo disables Stylix's `gtk` target (modules/generic/theme.nix), so
      # nothing else sets the GTK3/4 dark preference in settings.ini. Adwaita
      # (the active theme) is dual-variant; this makes GTK3 apps load its dark
      # half and GTK4 ones advertise dark to libadwaita apps.
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

    # dconf color-scheme has three writers: Stylix's `gnome` target (polarity
    # → "prefer-dark"/"default"), HM's gtk3 module ("prefer-${gtk.colorScheme}"
    # — same value as ours, but a separate plain-priority def), and this one.
    # Under the dark variant Stylix's and HM's values coincide and merge
    # silently; under light they diverge ("default" vs "prefer-light") and the
    # key stops evaluating — but only when forced, i.e. on a real rebuild,
    # never in lazily-evaluated tests (regression: j10s local-lab). marchyo
    # owns the variant knob, so its intent wins with mkForce; the dropped
    # Stylix value is cosmetic (Stylix notes it only drives Epiphany's
    # website dark-mode request, which prefer-dark/prefer-light serve too).
    dconf.settings."org/gnome/desktop/interface"."color-scheme" = lib.mkForce "prefer-${colorScheme}";
  };
}
