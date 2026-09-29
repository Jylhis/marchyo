# Global (headless-safe) bootloader; the greetd greeter block is desktop-gated.
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

  # greetd runs the marchyo Quickshell greeter (packages/marchyo-shell, greeter/
  # tree) under cage as a kiosk compositor; quickshell speaks the greetd protocol
  # natively (Quickshell.Services.Greetd) to authenticate and launch
  # `uwsm start hyprland-uwsm.desktop`. The greeter is a FloatingWindow (plain
  # xdg-toplevel), NOT a layer-shell PanelWindow: cage has no wlr-layer-shell, so
  # a layer surface would never map and the screen would stay black.
  # dbus-run-session gives it a session bus; cage -s keeps VT switching as the
  # escape hatch if the greeter fails to render (Ctrl+Alt+F2, then rollback).
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

  # Last-user cache for the greeter's username prefill, written by the greeter
  # (as user `greeter`); same tmpfiles idiom the nixpkgs greetd module uses.
  systemd.tmpfiles.rules = lib.mkIf cfg.desktop.enable [
    "d '/var/cache/marchyo-greeter' - greeter greeter - -"
  ];
}
