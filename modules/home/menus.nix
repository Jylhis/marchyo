# Omarchy-style power/session menu (SUPER+Escape): a gum TUI launched in a
# floating ghostty window, reusing the org.omarchy.terminal class so the
# centered floating-window rule from hyprland.nix applies (same pattern as
# keybindings-cheatsheet.nix).
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
in
{
  config = mkIf enabled {
    home.packages = [
      powerMenu
    ];

    # Merges with the bindd lists from hyprland.nix / screenshot.nix /
    # webapps.nix (home-manager concatenates the lists). The combo was
    # verified free in hyprland.nix.
    wayland.windowManager.hyprland.settings.bindd = [
      "SUPER, Escape, Power menu, exec, $terminal --class=org.omarchy.terminal -e marchyo-power-menu"
    ];
  };
}
