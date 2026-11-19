{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.notifications.unitFailures;

  watcher = pkgs.writeShellApplication {
    name = "marchyo-unit-failure-watch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
      pkgs.marchyo-cli
    ];
    text = builtins.readFile ./unit-failure-watch.sh;
  };

  # Through a file: Environment= mangles backslashes, % and spaces.
  ignoreFile = pkgs.writeText "marchyo-unit-failure-ignore" (
    lib.concatMapStrings (glob: glob + "\n") cfg.ignore
  );
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.marchyo-unit-failure-watch = {
      description = "Notify when a systemd unit fails";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = lib.getExe watcher;
        Restart = "on-failure";
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = "AF_UNIX";
        TasksMax = 64;
        MemoryMax = "512M";
        Environment = [ "MARCHYO_UNIT_FAILURE_IGNORE_FILE=${ignoreFile}" ];
      };
    };
  };
}
