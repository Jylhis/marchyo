{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ../../assets/applications/waybar.css;
    settings = [
      {
        "reload_style_on_change" = true;
        layer = "top";
        position = "top";
        spacing = 0;
        height = 26;
        modules-left = [
          # "custom/omarchy"
          "hyprland/workspaces"
        ];
        modules-center = [
          "clock"
        ];
        modules-right = [
          "group/tray-expander"
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
        "custom/omarchy" = {
          "format" = "<span font='omarchy-ttf'>\ue900</span>";
          "on-click" = "omarchy-menu";
          "tooltip-format" = "Omarchy Menu\n\nSuper + Alt + Space";
        };
        cpu = {
          interval = 5;
          format = "󰍛";
          on-click = "kitty -e btop"; # FIXME
        };
        clock = {
          format = "{:L%A %H:%M}";
          format-alt = "{:L%d %B W%V %Y}";
          tooltip = false;
          on-click-right = "omarchy-cmd-tzupdate"; # FIXME
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
          on-click = "kitty -e impala";
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
          on-click = "omarchy-menu power";
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
          on-click = "kitty -e bluetui";
        };
        wireplumber = {
          # Changed from "pulseaudio"
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
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; # Updated command
          # "on-click": "$TERMINAL --class=Wiremix -e wiremix",
          # "on-click-right": "pamixer -t",
          max-volume = 150; # Optional: allow volume over 100%
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
        "custom/light_dark" = {
          "format" = "󰔎 ";
          "on-click" = "$HOME/.config/hypr/scripts/DarkLight.sh"; # TODO
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
}
