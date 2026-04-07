# System-level collectors: auditd + inotifywait file watcher.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  sysCfg = cfg.system;
  mUsers = builtins.attrNames config.marchyo.users;

  fileWatchScript = pkgs.writeShellScript "marchyo-tracking-file-watch" ''
    set -eu
    OUT="$HOME/${cfg.dataDir}"
    ${pkgs.coreutils}/bin/mkdir -p "$OUT"
    WATCH_DIRS=()
    [ -d "$HOME/Developer" ] && WATCH_DIRS+=("$HOME/Developer")
    [ -d "$HOME/.config" ]   && WATCH_DIRS+=("$HOME/.config")
    if [ ''${#WATCH_DIRS[@]} -eq 0 ]; then
      exec ${pkgs.coreutils}/bin/sleep infinity
    fi
    exec ${pkgs.inotify-tools}/bin/inotifywait -m -r \
      --exclude '(\.git|node_modules|target|__pycache__|\.cache|result|\.direnv)' \
      -e close_write,create,delete,moved_to \
      --format '{"type":"file","ts":"%T","path":"%w%f","event":"%e"}' \
      --timefmt '%Y-%m-%dT%H:%M:%S' \
      "''${WATCH_DIRS[@]}" \
      >> "$OUT/file-changes.jsonl"
  '';
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf sysCfg.auditd {
        security.auditd.enable = true;
        security.audit = {
          enable = true;
          rules = [
            "-a always,exit -F arch=b64 -S execve -k exec_log"
          ]
          ++ map (u: "-w ${config.users.users.${u}.home}/.config -p wa -k config_changes") mUsers;
        };
      })

      (lib.mkIf sysCfg.fileWatch {
        boot.kernel.sysctl."fs.inotify.max_user_watches" = lib.mkDefault 524288;

        environment.systemPackages = [ pkgs.inotify-tools ];

        systemd.user.services.marchyo-tracking-file-watch = {
          description = "Marchyo tracking: inotify file change watcher";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = 5;
            ExecStart = "${fileWatchScript}";
          };
        };
      })
    ]
  );
}
