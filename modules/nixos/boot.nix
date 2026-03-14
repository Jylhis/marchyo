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
    enable = true;
    configurationLimit = lib.mkDefault 5;
  };

  # Login (only when desktop is enabled)
  services.greetd = lib.mkIf cfg.desktop.enable {
    enable = true;
    settings.default_session.command =
      "${lib.getExe (pkgs.tuigreet or pkgs.greetd.tuigreet)} "
      + (lib.cli.toCommandLineShellGNU { } {
        time = true;
        cmd = "niri-session";
        remember = true;
        remember-session = true;
        user-menu = true;
      });
  };
}
