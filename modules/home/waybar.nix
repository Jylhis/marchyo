# Waybar configuration with systemd service override
#
# IMPORTANT: Waybar has a known bug with SIGUSR2 signal handling that causes
# multiple instances to spawn after sleep/wake cycles. The signal handler
# performs a "complete reinit over existing state" and registers new monitor
# event handlers without cleaning up old ones.
#
# References:
# - https://github.com/Alexays/Waybar/issues/3344 (Multiple instances after DPMS resume)
# - https://github.com/Alexays/Waybar/issues/3964 (SIGUSR2 opens multiple instances)
{
  lib,
  pkgs,
  ...
}:
let
  waybarStyle = builtins.readFile ../../assets/applications/waybar.css;
  terminal = "${pkgs.ghostty}/bin/ghostty";
in
{
  config = {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = waybarStyle;
      settings = [
        {
          "reload_style_on_change" = true;
          layer = "top";
          position = "top";
          spacing = 0;
          height = 26;
          modules-left = [
            "hyprland/workspaces"
          ];
          modules-center = [
            "clock"
          ];
          modules-right = [
            "group/tray-expander"
            "hyprland/language"
            "bluetooth"
            "network"
            "wireplumber"
            "cpu"
            "power-profiles-daemon"
            "battery"
          ];
          "hyprland/workspaces" = {
            on-click = "activate";
            format = "{icon}";
            format-icons = {
              default = "";
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "4" = "4";
              "5" = "5";
              "6" = "6";
              "7" = "7";
              "8" = "8";
              "9" = "9";
              active = "󱓻";
            };
            persistent-workspaces = {
              "1" = [ ];
              "2" = [ ];
              "3" = [ ];
              "4" = [ ];
              "5" = [ ];
            };
          };
          "hyprland/language" = {
            format = "{short}";
            tooltip-format = "{long}";
          };
          cpu = {
            interval = 5;
            format = "󰍛";
            on-click = "${terminal} -e ${pkgs.btop}/bin/btop";
          };
          clock = {
            format = "{:L%A %H:%M}";
            format-alt = "{:L%d %B W%V %Y}";
            tooltip = false;
          };
          network = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format = "{icon}";
            format-wifi = "{icon}";
            format-ethernet = "󰀂";
            format-disconnected = "󰖪";
            tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
            tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
            tooltip-format-disconnected = "Disconnected";
            interval = 3;
            nospacing = 1;
            on-click = "${terminal} -e ${pkgs.impala}/bin/impala";
          };
          battery = {
            interval = 5;
            format = "{capacity}% {icon}";
            format-discharging = "{icon}";
            format-charging = "{icon}";
            format-plugged = "";
            format-icons = {
              charging = [
                "󰢜"
                "󰂆"
                "󰂇"
                "󰂈"
                "󰢝"
                "󰂉"
                "󰢞"
                "󰂊"
                "󰂋"
                "󰂅"
              ];
              default = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            format-full = "󰂅";
            on-click = "vicinae toggle";
            tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
            tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
            states = {
              warning = 20;
              critical = 10;
            };
          };
          bluetooth = {
            format = "󰂯";
            format-disabled = "󰂲";
            format-connected = "";
            tooltip-format = "Devices connected: {num_connections}";
            on-click = "${terminal} -e ${pkgs.bluetui}/bin/bluetui";
          };
          wireplumber = {
            format = "{icon}";
            format-icons = {
              default = [
                ""
                ""
                ""
              ];
            };
            format-muted = "";
            scroll-step = 5;
            on-click = "pavucontrol";
            tooltip-format = "Playing at {volume}%";
            on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            max-volume = 150;
          };
          tray = {
            spacing = 13;
            icon-size = 12;
          };
          "group/tray-expander" = {
            "orientation" = "inherit";
            "drawer" = {
              "transition-duration" = 600;
              "children-class" = "tray-group-item";
            };
            "modules" = [
              "custom/expand-icon"
              "tray"
            ];
          };
          "custom/expand-icon" = {
            "format" = " ";
            "tooltip" = false;
          };
          power-profiles-daemon = {
            format = "{icon}";
            tooltip-format = "Power profile: {profile}";
            tooltip = true;
            format-icons = {
              power-saver = "󰡳";
              balanced = "󰊚";
              performance = "󰡴";
            };
          };
        }
      ];
    };

    # Override the systemd service to use full restart instead of SIGUSR2
    # This prevents the bug where SIGUSR2 causes multiple waybar instances
    systemd.user.services.waybar = {
      Service = {
        # Override ExecReload to use full restart instead of SIGUSR2
        ExecReload = lib.mkForce [
          ""
          "${pkgs.systemd}/bin/systemctl --user restart waybar.service"
        ];
      };
    };
  };
}
