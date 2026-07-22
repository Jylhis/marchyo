# Backing scripts for the omarchy-style window/system toggle keybinds wired in
# modules/home/hyprland.nix. omarchy drives these from `omarchy-*` shell
# scripts that do not exist here, so marchyo ships its own small wrappers
# (mirroring how the media keys were translated to direct commands).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # Cursor zoom moved to `marchyo zoom in|out|reset` (commands/launch.ts).
  # Nightlight, idle-lock, notification-DND, and screen-recording toggles
  # were absorbed into the marchyo CLI (`marchyo toggle …` /
  # `marchyo capture record`, packages/marchyo-cli) — same actuation
  # commands, state now tracked as CLI runtime overrides / live probes.
  # The recorder/notify tools the CLI drives stay installed here.
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

    # Merges with the bindd lists from hyprland.nix / screenshot.nix /
    # webapps.nix (home-manager concatenates the lists; order is irrelevant
    # to Hyprland). Dismiss-all moved here from SUPER CTRL, comma in
    # hyprland.nix, which now belongs to the DND toggle (omarchy parity).
    wayland.windowManager.hyprland.settings.bindd = [
      "SUPER CTRL, comma, Toggle do-not-disturb, exec, marchyo toggle notifications"
      "SUPER CTRL SHIFT, comma, Dismiss all notifications, exec, makoctl dismiss --all"
    ];
  };
}
