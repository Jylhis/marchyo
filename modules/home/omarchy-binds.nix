# Omarchy-parity keybinds (OMARCHY_PARITY.md Phase 2): monitor-control
# helpers, connectivity TUIs in floating terminals, and app-launch binds.
# Scripts follow the modules/home/window-toggles.nix writeShellApplication
# pattern; binds merge into the bindd list the same way
# modules/home/webapps.nix does (home-manager concatenates the lists, order
# is irrelevant to Hyprland). `$terminal` and the org.omarchy.* floating
# window classes are defined in modules/home/hyprland.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.isLinux && (marchyoCfg.desktop.enable or false);
  devEnabled = marchyoCfg.development.enable or false;

  # Same resolution as $fileManager in modules/home/hyprland.nix: follow
  # marchyo.defaults.fileManager, fall back to xdg-open when unmanaged (null).
  fileManagerPackages = {
    inherit (pkgs) nautilus;
    inherit (pkgs.xfce) thunar;
  };
  fileManagerName = (marchyoCfg.defaults or { }).fileManager or "nautilus";
  fileManagerBin = if fileManagerName == null then "xdg-open" else fileManagerName;
  fileManagerDeps =
    if fileManagerName == null then [ pkgs.xdg-utils ] else [ fileManagerPackages.${fileManagerName} ];

  # Cycle the focused monitor's scale through 1 -> 1.25 -> 1.5 -> 1.75 -> 2 -> 1
  # while preserving the current mode and position. Note Hyprland clamps scales
  # to values that yield an integer pixel size, so some panels skip steps.
  marchyo-monitor-scale-cycle = pkgs.writeShellApplication {
    name = "marchyo-monitor-scale-cycle";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
    ];
    text = ''
      mon=$(hyprctl monitors -j \
        | jq -r '[.[] | select(.focused)][0] // empty | "\(.name) \(.scale) \(.width) \(.height) \(.refreshRate) \(.x) \(.y)"')
      if [ -z "$mon" ]; then
        echo "marchyo-monitor-scale-cycle: no focused monitor found" >&2
        exit 1
      fi
      read -r name current width height refresh x y <<<"$mon"
      # jq may normalize numbers (1.00 -> 1) or keep the input literal; the
      # extra arms cover both. Anything off-cycle snaps back to 1.
      case "$current" in
        1 | 1.0 | 1.00) next=1.25 ;;
        1.25) next=1.5 ;;
        1.5 | 1.50) next=1.75 ;;
        1.75) next=2 ;;
        *) next=1 ;;
      esac
      hyprctl keyword monitor "$name,''${width}x''${height}@''${refresh},''${x}x''${y},$next"
    '';
  };

  # Toggle the built-in laptop panel (any eDP* output) on/off, e.g. when
  # docking. `monitors all -j` includes disabled outputs (with a .disabled
  # flag), so one call finds the panel and its last reported geometry, which
  # the re-enable path restores when it looks sane.
  marchyo-laptop-display-toggle = pkgs.writeShellApplication {
    name = "marchyo-laptop-display-toggle";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
    ];
    text = ''
      mon=$(hyprctl monitors all -j \
        | jq -r '[.[] | select(.name | test("^eDP"))][0] // empty | "\(.name) \(.disabled) \(.width) \(.height) \(.refreshRate) \(.x) \(.y) \(.scale)"')
      if [ -z "$mon" ]; then
        echo "marchyo-laptop-display-toggle: no laptop display (eDP*) found" >&2
        exit 1
      fi
      read -r name disabled width height refresh x y scale <<<"$mon"
      if [ "$disabled" = "true" ]; then
        # A long-disabled output can report zeroed mode/scale fields; fall back
        # to preferred/auto per field instead of feeding Hyprland a 0x0 mode.
        mode=preferred
        pos=auto
        case "$refresh" in "" | 0 | 0.*) refresh="" ;; esac
        case "$scale" in "" | 0 | 0.*) scale=auto ;; esac
        if [ "$width" -gt 0 ] 2>/dev/null && [ "$height" -gt 0 ] 2>/dev/null; then
          mode="''${width}x''${height}''${refresh:+@$refresh}"
          pos="''${x}x''${y}"
        fi
        hyprctl keyword monitor "$name,$mode,$pos,$scale"
      else
        hyprctl keyword monitor "$name,disable"
      fi
    '';
  };

  # Open the default file manager at the focused terminal's working directory:
  # resolve the active window's PID, prefer its first child (the shell running
  # inside the terminal), and read /proc/<pid>/cwd. Falls back to $HOME.
  marchyo-file-manager-cwd = pkgs.writeShellApplication {
    name = "marchyo-file-manager-cwd";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
      pkgs.procps
      pkgs.coreutils
    ]
    ++ fileManagerDeps;
    text = ''
      dir=$HOME
      pid=$(hyprctl activewindow -j | jq -r '.pid // empty')
      if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
        child=$(pgrep -P "$pid" 2>/dev/null | head -n 1 || true)
        for p in "$child" "$pid"; do
          if [ -z "$p" ]; then
            continue
          fi
          cwd=$(readlink -f "/proc/$p/cwd" 2>/dev/null || true)
          if [ -n "$cwd" ] && [ -d "$cwd" ]; then
            dir=$cwd
            break
          fi
        done
      fi
      exec ${fileManagerBin} "$dir"
    '';
  };
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      marchyo-monitor-scale-cycle
      marchyo-laptop-display-toggle
      marchyo-file-manager-cwd
      # Backs the SUPER+ALT+Return work-session bind; not installed elsewhere.
      pkgs.tmux
    ];

    wayland.windowManager.hyprland.settings.bindd = [
      # --- Monitor controls ---
      # SUPER+/ (slash) is the password manager, so the scale cycle sits on the
      # adjacent backslash.
      "SUPER, backslash, Cycle monitor scale, exec, marchyo-monitor-scale-cycle"
      "SUPER CTRL, Delete, Toggle laptop display, exec, marchyo-laptop-display-toggle"

      # --- Connectivity TUIs (floating, omarchy setup-menu parity) ---
      # Same TUIs waybar's segments launch (wiremix/impala/bluetui, all in
      # modules/nixos/packages.nix tuiTools); the org.omarchy.* classes are
      # matched by the floating-window tag rule in modules/home/hyprland.nix.
      "SUPER CTRL, A, Audio mixer, exec, $terminal --class=org.omarchy.wiremix -e wiremix"
      "SUPER CTRL, B, Bluetooth manager, exec, $terminal --class=org.omarchy.bluetui -e bluetui"
      "SUPER CTRL, W, Wi-Fi manager, exec, $terminal --class=org.omarchy.impala -e impala"

      # --- App launches ---
      "SUPER ALT, return, tmux Work session, exec, $terminal -e tmux new -A -s Work"
      "SUPER ALT SHIFT, F, File manager at terminal cwd, exec, marchyo-file-manager-cwd"
    ]
    ++ lib.optionals devEnabled [
      # lazydocker is system-side via marchyo.development.enable (devTools in
      # modules/nixos/packages.nix), so the bind follows the same gate.
      "SUPER ALT, D, Docker TUI, exec, $terminal --class=org.omarchy.terminal -e lazydocker"
    ];
  };
}
