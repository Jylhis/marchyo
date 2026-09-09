# Desktop-only: the Hyprland screen locker and its PAM service.
{ config, lib, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.desktop.enable {
    programs.hyprlock.enable = lib.mkDefault true;
    security.pam.services.hyprlock = { };
  };
}
