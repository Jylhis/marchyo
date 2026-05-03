# Per-user ActivityWatch and awatcher configuration.
#
# Writes XDG config files for aw-server-rust and awatcher. The systemd
# user services are declared in modules/nixos/tracking/desktop.nix; this
# module only handles the config-file side.
{
  osConfig,
  lib,
  ...
}:
let
  trackingCfg = osConfig.marchyo.tracking or { };
  enabled = (trackingCfg.enable or false) && (trackingCfg.desktop.enable or false);
in
{
  config = lib.mkIf enabled {
    # aw-server-rust: bind to localhost only, default port 5600.
    xdg.configFile."activitywatch/aw-server-rust/config.toml".text = ''
      [server]
      host = "127.0.0.1"
      port = 5600
    '';

    # awatcher: Wayland-native window/idle watcher.
    # idle-timeout-seconds  = mark idle after 3 minutes of no input
    # poll-time-idle-seconds = check idle state every 4 s
    # poll-time-window-seconds = check active window every 1 s
    xdg.configFile."awatcher/config.toml".text = ''
      [server]
      host = "127.0.0.1"
      port = 5600

      [awatcher]
      idle-timeout-seconds = 180
      poll-time-idle-seconds = 4
      poll-time-window-seconds = 1
    '';
  };
}
