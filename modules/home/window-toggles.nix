# Notification/DND and screen-recording toggle binds (wired in
# modules/home/hyprland.nix) plus the recorder/notify tools the marchyo CLI
# drives. omarchy's `omarchy-*` scripts do not exist here, so marchyo routes
# these through the CLI (`marchyo toggle …` / `marchyo capture record`).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  # When the unified shell owns notifications, DND is in-shell state and mako is
  # gone, so these binds reach the shell over IPC instead of the CLI/makoctl.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      # Tools `marchyo capture record` drives (the CLI shells out to them).
      pkgs.gpu-screen-recorder
      pkgs.slurp
      pkgs.libnotify
      pkgs.procps
    ];

    wayland.windowManager.hyprland.settings.bind =
      if shellEnabled then
        [
          (hlua.bindd "SUPER + CTRL + comma" "Toggle do-not-disturb" (
            hlua.exec "marchyo-shell ipc -n call -- shell toggleDnd"
          ))
          (hlua.bindd "SUPER + CTRL + SHIFT + comma" "Dismiss all notifications" (
            hlua.exec "marchyo-shell ipc -n call -- shell clearNotifications"
          ))
          (hlua.bindd "SUPER + N" "Notification centre (history)" (
            hlua.exec "marchyo-shell ipc -n call -- shell toggleNotifications"
          ))
        ]
      else
        [
          (hlua.bindd "SUPER + CTRL + comma" "Toggle do-not-disturb" (
            hlua.exec "marchyo toggle notifications"
          ))
          (hlua.bindd "SUPER + CTRL + SHIFT + comma" "Dismiss all notifications" (
            hlua.exec "makoctl dismiss --all"
          ))
        ];
  };
}
