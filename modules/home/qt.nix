# Qt apps follow the live GTK surface.
#
# Stylix's `qt` target is opted out (modules/generic/theme.nix); instead the
# session runs `QT_QPA_PLATFORMTHEME=gtk3`, so Qt reads marchyo's GTK settings
# (theme, icons, font) and follows the runtime theme layer: the gtk.css relink
# and the dconf color-scheme write restyle Qt together with GTK. Both nixpkgs
# qtbase generations ship the gtk3 platform-theme plugin (libqgtk3.so), so no
# extra package is needed. The marchyo-shell wrapper pins the same value for
# the shell process itself (packages/marchyo-shell/package.nix), which has no
# osConfig to read; the greeter deliberately keeps the Qt default (session-less
# user, no GTK settings).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
in
{
  config = lib.mkIf desktopEnabled {
    home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkDefault "gtk3";
  };
}
