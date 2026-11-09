# Stands down when the unified Quickshell shell owns the lock (Phase 4),
# matching the Home-Manager hyprlock module.
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
