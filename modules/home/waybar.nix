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
  config,
  pkgs,
  ...
}:
let
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  hex = color: "#${color}";

  # fcitx5 status script for waybar
  # Shows current input method: keyboard layouts (us, fi, cn) or IME (拼, あ, 한)
  fcitx5StatusScript = pkgs.writeShellScript "fcitx5-status.sh" ''
    # Get current fcitx5 input method name
    status=$(${pkgs.fcitx5}/bin/fcitx5-remote -n 2>/dev/null)

    # Check if fcitx5 is running
    if [ -z "$status" ]; then
        echo '{"text":"","class":"inactive","tooltip":"fcitx5 not running"}'
        exit 0
    fi

    # Handle different input methods
    case "$status" in
        keyboard-*)
            # Extract layout code from keyboard-us, keyboard-fi, etc.
            layout=''${status#keyboard-}
            # Show first 2 chars of layout code (e.g., "us", "fi", "cn")
            echo '{"text":"'"''${layout:0:2}"'","class":"keyboard","tooltip":"Keyboard: '"$layout"'"}'
            ;;
        pinyin)
            echo '{"text":"拼","class":"ime-active","tooltip":"Chinese Pinyin"}'
            ;;
        mozc)
            echo '{"text":"あ","class":"ime-active","tooltip":"Japanese Mozc"}'
            ;;
        hangul)
            echo '{"text":"한","class":"ime-active","tooltip":"Korean Hangul"}'
            ;;
        unicode)
            echo '{"text":"⌨","class":"ime-active","tooltip":"Unicode Picker"}'
            ;;
        *)
            # Fallback for unknown input methods - show first 2 chars
            echo '{"text":"'"''${status:0:2}"'","class":"ime-active","tooltip":"'"$status"'"}'
            ;;
    esac
  '';

  # Generate CSS with colorScheme
  styleWithColors =
    if colors != null then
      ''
        @define-color background ${hex colors.base00};
        @define-color foreground ${hex colors.base05};
        @define-color border ${hex colors.base03};
        @define-color accent ${hex colors.base0D};
        @define-color urgent ${hex colors.base08};
        @define-color warning ${hex colors.base0A};

      ''
      + builtins.readFile ../../assets/applications/waybar.css
    else
      builtins.readFile ../../assets/applications/waybar.css;
in
{
  config = {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = styleWithColors;
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
            "custom/fcitx5"
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
          "custom/fcitx5" = {
            exec = "${fcitx5StatusScript}";
            return-type = "json";
            interval = 1;
            format = "{}";
            on-click = "${pkgs.qt6Packages.fcitx5-configtool}/bin/fcitx5-configtool";
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
