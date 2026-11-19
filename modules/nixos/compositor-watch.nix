{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.desktop;
  enabled = cfg.enable && cfg.compositorWatch.enable;

  watcher = pkgs.writeShellApplication {
    name = "marchyo-compositor-watch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      config.programs.hyprland.package
    ];
    text = builtins.readFile ./compositor-watch.sh;
  };

  keepLog = pkgs.writeShellApplication {
    name = "marchyo-hyprland-keep-log";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./hyprland-keep-log.sh;
  };
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = [ watcher ];

    systemd.user.services.marchyo-compositor-watch = {
      description = "Restart a hung Hyprland";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = lib.getExe watcher;
        Restart = "on-failure";
        # It reads /proc/<pid> of Hyprland, signals it and talks to its socket,
        # so no namespace or filesystem isolation is set here.
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = "AF_UNIX";
        TasksMax = 64;
        MemoryMax = "256M";
      };
    };

    # The compositor log lives on tmpfs and is gone at the next boot. nixpkgs'
    # uwsm module already makes this entry a drop-in for uwsm's template unit.
    systemd.user.services."wayland-wm@" = lib.mkIf config.programs.hyprland.withUWSM {
      serviceConfig.ExecStopPost = "-${lib.getExe keepLog}";
    };
  };
}
