{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  kbdCfg = (osConfig.marchyo or { }).keyboard or { layouts = [ ]; };
in
{
  config = lib.mkIf (desktopEnabled && kbdCfg.layouts != [ ]) {
    # For older GTK apps that predate Wayland text-input-v3; modern GTK 3/4 use it natively.
    xdg.configFile = {
      "gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-im-module=fcitx
      '';

      "gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-im-module=fcitx
      '';
    };
  };
}
