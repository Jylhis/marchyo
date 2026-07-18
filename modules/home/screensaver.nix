# tte-based terminal screensaver (omarchy parity). `marchyo-screensaver` plays
# random terminaltexteffects animations over a "marchyo" ASCII banner until any
# key is pressed; `marchyo-screensaver-launch` is the hypridle idle hook
# (modules/home/hypridle.nix) that opens it in a fullscreen ghostty window
# unless hyprlock owns the display. The `Screensaver` window class is matched
# by the existing fullscreen rule in modules/home/hyprland.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  screensaverEnabled = (osConfig.marchyo or { }).screensaver.enable or true;

  marchyo-screensaver = pkgs.writeShellApplication {
    name = "marchyo-screensaver";
    runtimeInputs = [
      pkgs.terminaltexteffects
      pkgs.coreutils
    ];
    text = ''
      effects=(matrix rain beams decrypt slide)

      banner=$(mktemp)
      cleanup() {
        if [ -n "''${tte_pid:-}" ]; then
          kill "$tte_pid" 2>/dev/null || true
        fi
        rm -f "$banner"
      }
      trap cleanup EXIT

      cat > "$banner" <<'EOF'
                          _
 _ __ ___   __ _ _ __ ___| |__  _   _  ___
| '_ ` _ \ / _` | '__/ __| '_ \| | | |/ _ \
| | | | | | (_| | | | (__| | | | |_| | (_) |
|_| |_| |_|\__,_|_|  \___|_| |_|\__, |\___/
                                |___/
EOF

      while true; do
        effect=''${effects[RANDOM % ''${#effects[@]}]}
        tte --input-file "$banner" --frame-rate 60 \
          --canvas-width 0 --canvas-height 0 --anchor-canvas c --anchor-text c \
          "$effect" &
        tte_pid=$!
        # tte has no exit-on-input flag, so watch stdin ourselves and stop the
        # whole show (closing the ghostty window) on any keypress.
        while kill -0 "$tte_pid" 2>/dev/null; do
          if read -rs -n 1 -t 0.2; then
            exit 0
          fi
        done
        tte_pid=""
        # Hold the finished frame briefly before the next effect; a keypress
        # during the pause exits too.
        if read -rs -n 1 -t 3; then
          exit 0
        fi
      done
    '';
  };

  marchyo-screensaver-launch = pkgs.writeShellApplication {
    name = "marchyo-screensaver-launch";
    runtimeInputs = [
      pkgs.procps
      pkgs.ghostty
    ];
    text = ''
      # Never draw over the lock screen (hyprlock renders above anyway and the
      # screensaver would keep running underneath).
      if pgrep -x hyprlock >/dev/null; then
        exit 0
      fi
      exec ghostty --class=Screensaver -e ${lib.getExe marchyo-screensaver}
    '';
  };
in
{
  config = lib.mkIf (desktopEnabled && screensaverEnabled) {
    home.packages = [
      marchyo-screensaver
      marchyo-screensaver-launch
    ];
  };
}
