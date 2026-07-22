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

  # Cursor zoom (screen magnifier). Steps cursor:zoom_factor without jq.
  marchyo-zoom = pkgs.writeShellApplication {
    name = "marchyo-zoom";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.gawk
    ];
    text = ''
      # `float:` may be tab-indented depending on Hyprland version, so do not
      # anchor the match; awk splits on whitespace either way.
      current=$(hyprctl getoption cursor:zoom_factor | awk '/float:/ {print $2; exit}')
      [ -n "$current" ] || current=1
      case "''${1:-}" in
        in)    new=$(awk -v c="$current" 'BEGIN { printf "%.2f", c + 0.5 }') ;;
        out)   new=$(awk -v c="$current" 'BEGIN { n = c - 0.5; if (n < 1) n = 1; printf "%.2f", n }') ;;
        reset) new=1.0 ;;
        *)     echo "usage: marchyo-zoom in|out|reset" >&2; exit 1 ;;
      esac
      hyprctl keyword cursor:zoom_factor "$new"
    '';
  };

  # Nightlight, idle-lock, notification-DND, and screen-recording toggles
  # were absorbed into the marchyo CLI (`marchyo toggle …` /
  # `marchyo capture record`, packages/marchyo-cli) — same actuation
  # commands, state now tracked as CLI runtime overrides / live probes.
  # The recorder/notify tools the CLI drives stay installed here.
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      marchyo-zoom
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
