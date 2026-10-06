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
    # org.freedesktop.Notifications from the marchyo shell (or mako with
    # marchyo.shell.enable = false). marchyo already covers the bar and the
    # launcher: the marchyo shell, or waybar and vicinae with the shell off.
    programs.noctalia.enable = lib.mkDefault false;
  };
}
