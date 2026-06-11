{ config, lib, ... }:
{
  # Screen locker for the Hyprland session — desktop-only.
  config = lib.mkIf config.marchyo.desktop.enable {
    programs.hyprlock.enable = true;
    security.pam.services.hyprlock = { };
  };
}
