{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
in
{
  config = lib.mkIf desktopEnabled {
    # Disabled: noctalia-shell is a full Quickshell desktop shell that ships its
    # own notification daemon (rendered as a large panel/window) and would seize
    # org.freedesktop.Notifications, overriding mako. marchyo already covers the
    # bar (waybar) and launcher (vicinae), so notifications go through mako.
    programs.noctalia.enable = lib.mkDefault false;
  };
}
