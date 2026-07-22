# Omarchy-style power/session menu (SUPER+Escape) and central system menu
# (SUPER+ALT+Space). Both are gum TUIs launched in a floating ghostty window,
# reusing the org.omarchy.terminal class so the centered floating-window rule
# from hyprland.nix applies (same pattern as keybindings-cheatsheet.nix).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  desktopEnabled = pkgs.stdenv.isLinux && (osConfig.marchyo.desktop.enable or false);
  enabled = desktopEnabled && (osConfig.marchyo.menus.enable or true);

  # Power/session menu. Actions that outlive the menu window (hyprlock) are
  # detached with setsid so closing the floating terminal doesn't kill them.
  powerMenu = pkgs.writeShellApplication {
    name = "marchyo-power-menu";
    runtimeInputs = with pkgs; [
      gum
      util-linux # setsid
    ];
    text = ''
      choice=$(
        gum choose \
          --header "Power" \
          "Lock" "Suspend" "Hibernate" "Relaunch" "Reboot" "Shutdown"
      ) || exit 0

      case "$choice" in
        Lock)
          setsid -f hyprlock >/dev/null 2>&1
          ;;
        Suspend)
          systemctl suspend
          ;;
        Hibernate)
          systemctl hibernate
          ;;
        Relaunch)
          # The session is started by greetd via `uwsm start` (see
          # modules/nixos/boot.nix), so ending it cleanly goes through uwsm;
          # greetd then shows the greeter again. Fall back to a plain
          # compositor exit, then to terminating the whole login session.
          if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then
            uwsm stop
          elif command -v hyprctl >/dev/null 2>&1; then
            hyprctl dispatch exit
          else
            loginctl terminate-user "$USER"
          fi
          ;;
        Reboot)
          systemctl reboot
          ;;
        Shutdown)
          systemctl poweroff
          ;;
      esac
    '';
  };

  # Central system menu: a small hierarchical gum menu. TUI tools (wiremix,
  # nmtui, bluetui, hyprmon, the cheatsheet, the power menu) replace the menu
  # process via exec so they run in the same floating terminal; one-shot
  # desktop actions (screenshot, color pick) are detached with a short delay
  # so the floating window is gone before any region selection starts.
  systemMenu = pkgs.writeShellApplication {
    name = "marchyo-menu";
    runtimeInputs = with pkgs; [
      gum
      util-linux # setsid
      coreutils
      grimblast
      hyprpicker
      wiremix
      networkmanager # nmtui
      bluetui
      hyprmon
      power-profiles-daemon # powerprofilesctl
      powerMenu
    ];
    text = ''
      detach() {
        setsid -f "$BASH" -c "sleep 0.2; $*" >/dev/null 2>&1
      }

      while true; do
        main=$(
          gum choose \
            --header "Marchyo" \
            "Trigger" "Setup" "Style" "System" "Learn"
        ) || exit 0

        case "$main" in
          Trigger)
            sel=$(
              gum choose \
                --header "Trigger" \
                "Screenshot" "Screen record" "Color pick" "Back"
            ) || continue
            case "$sel" in
              Screenshot)
                detach "grimblast --notify --freeze copysave area"
                exit 0
                ;;
              "Screen record")
                detach "marchyo-screenrecord-toggle"
                exit 0
                ;;
              "Color pick")
                detach "hyprpicker -a"
                exit 0
                ;;
            esac
            ;;
          Setup)
            sel=$(
              gum choose \
                --header "Setup" \
                "Audio" "Wifi" "Bluetooth" "Monitors" "Power profile" "Back"
            ) || continue
            case "$sel" in
              Audio) exec wiremix ;;
              Wifi) exec nmtui ;;
              Bluetooth) exec bluetui ;;
              Monitors) exec hyprmon ;;
              "Power profile")
                # power-profiles-daemon may be replaced (e.g. TLP) — report
                # instead of aborting the whole menu under `set -e`.
                if ! current=$(powerprofilesctl get 2>/dev/null); then
                  gum style "power-profiles-daemon unavailable"
                  sleep 2
                  continue
                fi
                # Cycle power-saver -> balanced -> performance -> power-saver;
                # skip back to power-saver when a profile is unsupported.
                case "$current" in
                  power-saver) next=balanced ;;
                  balanced) next=performance ;;
                  *) next=power-saver ;;
                esac
                if ! powerprofilesctl set "$next" 2>/dev/null; then
                  next=power-saver
                  powerprofilesctl set "$next" 2>/dev/null || true
                fi
                gum style "Power profile: $next"
                sleep 1
                ;;
            esac
            ;;
          Style)
            sel=$(
              gum choose \
                --header "Style" \
                "Light" "Dark" "Back"
            ) || continue
            case "$sel" in
              Light|Dark)
                variant=$(printf '%s' "$sel" | tr '[:upper:]' '[:lower:]')
                # `marchyo theme set` writes /etc/marchyo/cli-state.json, which
                # can fail without privileges — report instead of aborting.
                if command -v marchyo >/dev/null 2>&1 && marchyo theme set "$variant"; then
                  gum style "Theme set to $variant - apply with: marchyo rebuild"
                else
                  gum style "Could not write CLI state; set marchyo.theme.variant = \"$variant\" and rebuild."
                fi
                sleep 2
                ;;
            esac
            ;;
          System)
            exec marchyo-power-menu
            ;;
          Learn)
            if command -v marchyo-keybindings >/dev/null 2>&1; then
              exec marchyo-keybindings
            fi
            gum style "Keybindings cheatsheet is disabled (marchyo.keybindingsHelp.enable)."
            sleep 2
            ;;
        esac
      done
    '';
  };
in
{
  config = mkIf enabled {
    home.packages = [
      powerMenu
      systemMenu
    ];

    # Merges with the bindd lists from hyprland.nix / screenshot.nix /
    # webapps.nix (home-manager concatenates the lists). Both combos were
    # verified free in hyprland.nix.
    wayland.windowManager.hyprland.settings.bindd = [
      "SUPER, Escape, Power menu, exec, $terminal --class=org.omarchy.terminal -e marchyo-power-menu"
      "SUPER ALT, Space, System menu, exec, $terminal --class=org.omarchy.terminal -e marchyo-menu"
    ];
  };
}
