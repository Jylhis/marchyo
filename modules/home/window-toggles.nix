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

  # Nightlight (blue-light filter): flip the running hyprsunset daemon between a
  # warm temperature and identity via its runtime CLI/IPC override.
  marchyo-nightlight-toggle = pkgs.writeShellApplication {
    name = "marchyo-nightlight-toggle";
    runtimeInputs = [
      pkgs.hyprsunset
      pkgs.libnotify
    ];
    text = ''
      # Off = restore neutral daylight (6500K, hyprsunset's baseline). Uses only
      # the confirmed --temperature runtime override (avoids the less-certain
      # --identity flag and the upstream-buggy `hyprctl hyprsunset reset`).
      state="''${XDG_RUNTIME_DIR:-/tmp}/marchyo-nightlight.on"
      if [ -f "$state" ]; then
        hyprsunset --temperature 6500
        rm -f "$state"
        notify-send -u low -a marchyo "Nightlight" "Off"
      else
        hyprsunset --temperature 4000
        : > "$state"
        notify-send -u low -a marchyo "Nightlight" "On (4000K)"
      fi
    '';
  };

  # Idle lock: start/stop the hypridle user service so the screen won't
  # auto-dim/lock (e.g. during a presentation).
  marchyo-idle-toggle = pkgs.writeShellApplication {
    name = "marchyo-idle-toggle";
    runtimeInputs = [
      pkgs.systemd
      pkgs.libnotify
    ];
    text = ''
      if systemctl --user is-active --quiet hypridle.service; then
        systemctl --user stop hypridle.service
        notify-send -u low -a marchyo "Idle lock" "Disabled — screen will stay awake"
      else
        systemctl --user start hypridle.service
        notify-send -u low -a marchyo "Idle lock" "Enabled"
      fi
    '';
  };

  # Notification do-not-disturb: flip mako's do-not-disturb mode (declared in
  # modules/home/mako.nix as `[mode=do-not-disturb] invisible=1`), then poke
  # the waybar custom/dnd indicator (signal = 9 in modules/home/waybar.nix)
  # so it refreshes immediately.
  marchyo-dnd-toggle = pkgs.writeShellApplication {
    name = "marchyo-dnd-toggle";
    runtimeInputs = [
      pkgs.mako
      pkgs.procps
    ];
    text = ''
      makoctl mode -t do-not-disturb
      pkill -SIGRTMIN+9 waybar || true
    '';
  };

  # Screen recording: toggle gpu-screen-recorder on a slurp-selected region.
  # SIGINT finalizes the mp4. Files land in ~/Videos/Recordings.
  marchyo-screenrecord-toggle = pkgs.writeShellApplication {
    name = "marchyo-screenrecord-toggle";
    runtimeInputs = [
      pkgs.gpu-screen-recorder
      pkgs.slurp
      pkgs.libnotify
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      recdir="$HOME/Videos/Recordings"
      # Match the full command line: the kernel truncates the process comm to
      # 15 chars ("gpu-screen-reco"), so -x on the 19-char name never matches.
      if pgrep -f gpu-screen-recorder >/dev/null; then
        pkill -INT -f gpu-screen-recorder
        notify-send -u low -a marchyo "Screen recording" "Saved to $recdir"
      else
        region=$(slurp -f "%wx%h+%x+%y") || exit 0
        mkdir -p "$recdir"
        out="$recdir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
        notify-send -u low -a marchyo "Screen recording" "Recording started"
        gpu-screen-recorder -w region -region "$region" -f 60 -o "$out" &
      fi
    '';
  };
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      marchyo-zoom
      marchyo-nightlight-toggle
      marchyo-idle-toggle
      marchyo-dnd-toggle
      marchyo-screenrecord-toggle
    ];

    # Merges with the bindd lists from hyprland.nix / screenshot.nix /
    # webapps.nix (home-manager concatenates the lists; order is irrelevant
    # to Hyprland). Dismiss-all moved here from SUPER CTRL, comma in
    # hyprland.nix, which now belongs to the DND toggle (omarchy parity).
    wayland.windowManager.hyprland.settings.bindd = [
      "SUPER CTRL, comma, Toggle do-not-disturb, exec, marchyo-dnd-toggle"
      "SUPER CTRL SHIFT, comma, Dismiss all notifications, exec, makoctl dismiss --all"
    ];
  };
}
