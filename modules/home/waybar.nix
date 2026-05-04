# Waybar configuration with systemd service override.
#
# IMPORTANT: Waybar has a known bug with SIGUSR2 signal handling that causes
# multiple instances to spawn after sleep/wake cycles. The signal handler
# performs a "complete reinit over existing state" and registers new monitor
# event handlers without cleaning up old ones.
#
# References:
# - https://github.com/Alexays/Waybar/issues/3344 (Multiple instances after DPMS resume)
# - https://github.com/Alexays/Waybar/issues/3964 (SIGUSR2 opens multiple instances)
#
# Theming: composes the upstream Jylhis design CSS (Roast or Paper) with a small
# marchyo overlay covering selectors not present upstream (wireplumber, bluetooth,
# power-profiles-daemon, hyprland/language, the tray expander). The upstream HM
# module's waybar target is disabled in modules/home/jylhis-theme.nix so we own
# the file.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };

  upstreamFile = if isDark then "style.css" else "style-paper.css";
  upstreamCss = builtins.readFile "${pkgs.jylhis-themes}/share/jylhis/waybar/${upstreamFile}";

  # marchyo additions — selectors and tweaks not in upstream design
  marchyoCss = ''

    /* marchyo additions — selectors not in upstream Jylhis design */
    #wireplumber,
    #bluetooth,
    #power-profiles-daemon,
    #hyprland-language,
    #custom-expand-icon {
      padding: 0 10px;
    }

    #wireplumber.muted,
    #network.disconnected {
      color: ${palette.hex."text-faint"};
    }

    #tray > .needs-attention {
      color: ${palette.hex.accent};
      -gtk-icon-effect: highlight;
    }
  '';

  terminal = "${pkgs.ghostty}/bin/ghostty";
in
{
  config = {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = upstreamCss + marchyoCss;
      settings = [
        {
          "reload_style_on_change" = true;
          layer = "top";
          position = "top";
          spacing = 0;
          height = 28;
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
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
            format = "{name}";
            disable-scroll = true;
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
            format = "cpu {usage}%";
            on-click = "${terminal} -e ${pkgs.btop}/bin/btop";
          };
          clock = {
            format = "{:%a %d %b · %H:%M}";
            format-alt = "{:%d %B W%V %Y}";
            tooltip = false;
          };
          network = {
            format-wifi = "{essid} {signalStrength}%";
            format-ethernet = "eth";
            format-disconnected = "offline";
            tooltip-format = "{ipaddr}  {ifname}";
            interval = 3;
            on-click = "${terminal} -e ${pkgs.impala}/bin/impala";
          };
          battery = {
            interval = 5;
            format = "bat {capacity}%";
            format-charging = "chg {capacity}%";
            format-plugged = "pwr";
            format-full = "bat full";
            on-click = "vicinae toggle";
            tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
            tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
            states = {
              warning = 20;
              critical = 10;
            };
          };
          bluetooth = {
            format = "bt";
            format-disabled = "bt off";
            format-connected = "bt {num_connections}";
            tooltip-format = "Devices connected: {num_connections}";
            on-click = "${terminal} -e ${pkgs.bluetui}/bin/bluetui";
          };
          wireplumber = {
            format = "vol {volume}%";
            format-muted = "vol mute";
            scroll-step = 5;
            on-click = "pavucontrol";
            tooltip-format = "Playing at {volume}%";
            on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            max-volume = 150;
          };
          tray = {
            spacing = 10;
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
            "format" = "·";
            "tooltip" = false;
          };
          power-profiles-daemon = {
            format = "{icon}";
            tooltip-format = "Power profile: {profile}";
            tooltip = true;
            format-icons = {
              power-saver = "eco";
              balanced = "bal";
              performance = "perf";
            };
          };
        }
      ];
    };

    # Override the systemd service to use full restart instead of SIGUSR2
    # This prevents the bug where SIGUSR2 causes multiple waybar instances
    systemd.user.services.waybar = {
      Service = {
        ExecReload = lib.mkForce [
          ""
          "${pkgs.systemd}/bin/systemctl --user restart waybar.service"
        ];
      };
    };
  };
}
