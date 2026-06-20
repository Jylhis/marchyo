{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  kbdCfg = (osConfig.marchyo or { }).keyboard or { layouts = [ ]; };

  # Normalize all layouts to uniform structure (same as NixOS module)

  # Check if any layout requires IME
in
{
  config = lib.mkIf (desktopEnabled && kbdCfg.layouts != [ ]) {
    # GTK settings for older GTK apps that don't support Wayland text-input-v3
    # Modern GTK 3/4 apps on Wayland use text-input-v3 protocol, but some older apps need this
    xdg.configFile = {
      # GTK 3 settings
      "gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-im-module=fcitx
      '';

      # GTK 4 settings
      "gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-im-module=fcitx
      '';
    };
  };
}
