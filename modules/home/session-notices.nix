# Once per graphical session, after the shell owns org.freedesktop.Notifications:
# announce new NEWS entries (`marchyo whats-new --notify`) and send the one-time
# welcome that opens the setup checklist (`marchyo setup --welcome`). Both
# commands tolerate failure and wait for the notification service themselves.
{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  mc = osConfig.marchyo;
  enabled = pkgs.stdenv.hostPlatform.isLinux && mc.desktop.enable && mc.shell.enable;
  marchyoCli = if mc.cli.enable then "marchyo" else lib.getExe pkgs.marchyo-cli;
in
{
  config = lib.mkIf enabled {
    systemd.user.services.marchyo-session-notices = {
      Unit = {
        Description = "Announce what changed and the first-login setup";
        After = [
          "graphical-session.target"
          "marchyo-shell.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "-${marchyoCli} whats-new --notify"
          "-${marchyoCli} setup --welcome"
        ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
