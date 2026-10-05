{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  boot.loader.systemd-boot = {
    enable = lib.mkDefault true;
    configurationLimit = lib.mkDefault 5;
  };

  services.greetd = lib.mkIf cfg.desktop.enable {
    enable = true;
    settings.default_session.command = lib.concatStringsSep " " [
      "${lib.getExe' pkgs.dbus "dbus-run-session"}"
      "--"
      "${lib.getExe pkgs.cage}"
      "-s"
      "-d"
      "--"
      "${lib.getExe' pkgs.marchyo-shell "marchyo-greeter"}"
    ];
  };

  systemd.tmpfiles.rules = lib.mkIf cfg.desktop.enable [
    "d '/var/cache/marchyo-greeter' - greeter greeter - -"
  ];
}
