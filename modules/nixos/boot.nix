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

  # Login. The graphical greeter is the marchyo Quickshell greeter
  # (packages/marchyo-shell, greeter/ tree): greetd runs cage as a kiosk
  # compositor which fullscreens the greeter's single toplevel window, and
  # quickshell speaks the greetd protocol natively (Quickshell.Services.Greetd)
  # to authenticate and launch `uwsm start hyprland-uwsm.desktop` — the same
  # session command tuigreet ran. The greeter is a FloatingWindow (a plain
  # xdg-toplevel), NOT a layer-shell PanelWindow: cage has no wlr-layer-shell
  # support, so a layer surface would never map and the screen would stay
  # black. dbus-run-session gives the greeter a session bus (same launcher
  # shape as the nixpkgs regreet module). cage -s keeps VT switching available
  # as the escape hatch if the greeter ever fails to render (Ctrl+Alt+F2, then
  # rollback).
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

  # Last-user cache for the greeter's username prefill (written by the
  # greeter's FileView as the greeter user; same tmpfiles idiom the nixpkgs
  # greetd module uses for /var/cache/tuigreet).
  systemd.tmpfiles.rules = lib.mkIf cfg.desktop.enable [
    "d '/var/cache/marchyo-greeter' - greeter greeter - -"
  ];
}
