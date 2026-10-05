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
  # gone, so these binds reach the shell through `marchyo shell` instead of
  # `marchyo toggle`/makoctl.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;
  # The store path when the CLI is not installed system-wide, so the shell binds
  # never depend on marchyo.cli.enable.
  cliEnabled = (osConfig.marchyo or { }).cli.enable or false;
  marchyoCli = if cliEnabled then "marchyo" else lib.getExe pkgs.marchyo-cli;
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
          (hlua.bindd "SUPER + CTRL + comma" "Toggle do-not-disturb" (hlua.exec "${marchyoCli} shell dnd"))
          (hlua.bindd "SUPER + CTRL + SHIFT + comma" "Dismiss all notifications" (
            hlua.exec "${marchyoCli} shell dismiss --all"
          ))
          (hlua.bindd "SUPER + N" "Notification centre (history)" (
            hlua.exec "${marchyoCli} shell toggle notifications"
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
