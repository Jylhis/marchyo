# tte-based terminal screensaver. `marchyo-screensaver-launch` is the hypridle
# idle hook (modules/home/hypridle.nix), opening a fullscreen ghostty window
# unless hyprlock owns the display. The window uses the org.omarchy.screensaver
# class because ghostty rejects dotless --class values (falling back to its
# default class); this module contributes the matching fullscreen window rule.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  screensaverEnabled = (osConfig.marchyo or { }).screensaver.enable or true;

  # With the unified shell on, its in-shell lock replaces hyprlock, so the
  # "never draw over the lock screen" guard must ask the shell.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;

  marchyo-screensaver = pkgs.writeShellApplication {
    name = "marchyo-screensaver";
    runtimeInputs = [
      pkgs.terminaltexteffects
      pkgs.coreutils
    ];
    text = ''
            effects=(rain beams decrypt slide burn)

            banner=$(mktemp)
            trap 'exit 0' INT TERM HUP
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
              # tte has no exit-on-input flag, so watch stdin ourselves and exit on any keypress.
              while kill -0 "$tte_pid" 2>/dev/null; do
                if read -rs -n 1 -t 0.2; then
                  exit 0
                fi
              done
              tte_pid=""
              # Hold the finished frame briefly; a keypress during the pause exits too.
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
    ]
    ++ lib.optionals shellEnabled [ pkgs.marchyo-shell ];
    text = ''
      # `marchyo toggle screensaver off` drops this marker; stay inert while off.
      if [ -e "''${XDG_RUNTIME_DIR:-/tmp}/marchyo-screensaver.off" ]; then
        exit 0
      fi
      # Never draw over the lock screen, and never stack a second instance.
      if pgrep -x hyprlock >/dev/null; then
        exit 0
      fi
      ${lib.optionalString shellEnabled ''
        # In-shell lock: never animate underneath a locked session. An IPC
        # failure means no shell is running; treat that as unlocked.
        if [ "$(marchyo-shell ipc -n call -- shell lockState 2>/dev/null || true)" = "locked" ]; then
          exit 0
        fi
      ''}
      if pgrep -f class=org.omarchy.screensaver >/dev/null; then
        exit 0
      fi
      # --gtk-single-instance=false keeps this window out of any running
      # ghostty instance (which would ignore --class and break the rule match).
      exec ghostty --class=org.omarchy.screensaver --gtk-single-instance=false \
        -e ${lib.getExe marchyo-screensaver}
    '';
  };
in
{
  config = lib.mkIf (desktopEnabled && screensaverEnabled) {
    home.packages = [
      marchyo-screensaver
      marchyo-screensaver-launch
    ];

    wayland.windowManager.hyprland.settings.window_rule = [
      {
        match.class = "org.omarchy.screensaver";
        fullscreen = true;
      }
    ];
  };
}
