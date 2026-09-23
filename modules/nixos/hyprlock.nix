# Desktop-only: the Hyprland screen locker and its PAM service. Stands down
# when the unified Quickshell shell owns the lock (Phase 4) — same
# mutual-exclusion cutover as waybar/mako/swayosd on the Home-Manager side.
{ config, lib, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf (cfg.desktop.enable && !cfg.shell.enable) {
    programs.hyprlock.enable = lib.mkDefault true;
    security.pam.services.hyprlock = { };
  };
}
