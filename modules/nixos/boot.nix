{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  # The greeter bakes the host's build-time theme variant, the same override
  # modules/home/marchyo-shell.nix applies to the user shell.
  greeterPkg = pkgs.marchyo-shell.override { inherit (cfg.theme) variant; };
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
      "${lib.getExe' greeterPkg "marchyo-greeter"}"
    ];
  };

  # /var/lib/marchyo/greeter holds theme.json, the session theme the greeter
  # follows (written by `marchyo theme set`). Mode 1775 root:users: session
  # users (group users) may create files, the sticky bit stops one user from
  # replacing or deleting another's marker, and the greeter user (not in
  # users) gets read and list access only.
  systemd.tmpfiles.rules = lib.mkIf cfg.desktop.enable [
    "d '/var/cache/marchyo-greeter' - greeter greeter - -"
    "d '/var/lib/marchyo/greeter' 1775 root users - -"
  ];
}
