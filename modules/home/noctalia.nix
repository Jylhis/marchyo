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
    # Disabled: noctalia's own notification daemon would seize
    # org.freedesktop.Notifications and override mako. marchyo already covers the
    # bar (waybar) and launcher (vicinae).
    programs.noctalia.enable = lib.mkDefault false;
  };
}
