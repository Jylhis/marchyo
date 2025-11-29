{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 5;
  };

  # Login
  services.greetd = {
    enable = true;
    settings.default_session.command =
      "${lib.getExe (pkgs.greetd.tuigreet or pkgs.tuigreet)} "
      + (lib.cli.toGNUCommandLineShell { } {
        time = true;
        cmd = "Hyprland";
        remember = true;
        remember-session = true;
        user-menu = true;
      });
  };
}
