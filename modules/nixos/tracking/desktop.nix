# Desktop activity tracking: ActivityWatch + awatcher + grim screenshots.
#
# - activitywatch-server provides the REST/storage layer at localhost:5600
# - awatcher is the Wayland-native window/idle watcher (wlr-foreign-toplevel
#   + ext-idle-notify). Default `aw-watcher-window` is X11 only and not used.
# - Screenshots run via grim on a systemd user timer with a hyprctl-based
#   privacy filter that skips password manager windows.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  desktopCfg = cfg.desktop;
  mUsers = builtins.attrNames config.marchyo.users;

  screenshotScript = pkgs.writeShellScript "marchyo-tracking-screenshot" ''
    set -eu
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    if ! command -v hyprctl >/dev/null 2>&1; then
      exit 0
    fi
    WIN=$(hyprctl activewindow -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.class // ""')
    case "$WIN" in
      *bitwarden*|*keepass*|*1password*|*bitwarden-desktop*)
        exit 0
        ;;
    esac
    DIR="$HOME/.local/share/screenshots/$(${pkgs.coreutils}/bin/date +%Y-%m-%d)"
    ${pkgs.coreutils}/bin/mkdir -p "$DIR"
    ${pkgs.grim}/bin/grim -t jpeg -q 50 \
      "$DIR/$(${pkgs.coreutils}/bin/date +%H-%M-%S).jpg"
  '';
in
{
  config = lib.mkIf (cfg.enable && desktopCfg.enable) (lib.mkMerge [
    {
      environment.systemPackages = with pkgs; [
        activitywatch
        awatcher
      ];

      # ActivityWatch server as a user service so its SQLite store lives
      # under ~/.local/share/activitywatch.
      systemd.user.services.activitywatch-server = {
        description = "ActivityWatch server";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.activitywatch}/bin/aw-server";
          Restart = "on-failure";
        };
      };

      systemd.user.services.awatcher = {
        description = "ActivityWatch Wayland watcher (awatcher)";
        wantedBy = [ "default.target" ];
        after = [ "activitywatch-server.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.awatcher}/bin/awatcher";
          Restart = "on-failure";
        };
      };
    }

    (lib.mkIf desktopCfg.screenshots.enable {
      environment.systemPackages = with pkgs; [
        grim
        jq
      ];

      systemd.user.services.marchyo-tracking-screenshot = {
        description = "Marchyo tracking: periodic activity screenshot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${screenshotScript}";
        };
      };

      systemd.user.timers.marchyo-tracking-screenshot = {
        description = "Marchyo tracking: periodic screenshot timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = desktopCfg.screenshots.interval;
          OnUnitActiveSec = desktopCfg.screenshots.interval;
          Unit = "marchyo-tracking-screenshot.service";
        };
      };

      # Retention: prune screenshots older than retentionDays for each
      # configured marchyo user. Uses absolute /home/<user> paths because
      # system tmpfiles does not have access to per-user %h expansion.
      systemd.tmpfiles.rules = map (
        u: "e /home/${u}/.local/share/screenshots - - - ${toString desktopCfg.screenshots.retentionDays}d -"
      ) mUsers;
    })
  ]);
}
