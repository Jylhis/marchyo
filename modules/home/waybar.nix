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
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  menusEnabled = (osConfig.marchyo or { }).menus.enable or true;
  dictation = (osConfig.marchyo or { }).dictation or { };
  voxtypeIndicator = (dictation.enable or false) && (dictation.indicator or true);
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };

  # Notification DND state for the custom/dnd module: one JSON object per
  # invocation (interval = "once"), re-run on SIGRTMIN+9 — sent by
  # marchyo-dnd-toggle (modules/home/window-toggles.nix) right after it flips
  # mako's do-not-disturb mode. Nerd-font bell glyphs match the voxtype
  # indicator's icon style.
  dndStatus = pkgs.writeShellApplication {
    name = "marchyo-dnd-status";
    runtimeInputs = [
      pkgs.mako
      pkgs.gnugrep
    ];
    text = ''
      if makoctl mode | grep -q do-not-disturb; then
        printf '{"text":"󰂛","class":"dnd","tooltip":"Do not disturb — notifications hidden"}\n'
      else
        printf '{"text":"󰂚","class":"idle","tooltip":"Notifications on"}\n'
      fi
    '';
  };

  upstreamFile = if isDark then "style.css" else "style-paper.css";
  upstreamCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/waybar/${upstreamFile}";

  # marchyo additions — selectors and tweaks not in upstream design
  marchyoCss = ''

    /* marchyo additions — selectors not in upstream Jylhis design */
    #wireplumber,
    #bluetooth,
    #power-profiles-daemon,
    #language,
    #custom-expand-icon {
      padding: 0 10px;
    }

    /* The upstream CSS styles #hyprland-language, but waybar's hyprland/language
       module renders as #language — apply the intended text-muted here. */
    #language {
      color: ${palette.hex."text-muted"};
    }

    #wireplumber.muted,
    #network.disconnected {
      color: ${palette.hex."text-faint"};
    }

    #tray > .needs-attention {
      color: ${palette.hex.accent};
      -gtk-icon-effect: highlight;
    }

    /* tmux-style TUI statusline — square segments, monospace, inverse active */
    * {
      border-radius: 0;
      font-family: "JetBrainsMono Nerd Font", monospace;
    }

    /* tmux session label */
    #custom-session {
      background: ${palette.hex.accent};
      color: ${palette.hex.bg};
      padding: 0 10px;
      font-weight: bold;
    }

    #workspaces button {
      border-radius: 0;
      padding: 0 8px;
      color: ${palette.hex."text-muted"};
    }

    /* inverse-video selected pane, like a highlighted tmux window */
    #workspaces button.active {
      background: ${palette.hex.accent};
      color: ${palette.hex.bg};
    }

    /* │ separators between right-hand status segments */
    #custom-voxtype,
    #custom-dnd,
    #language,
    #bluetooth,
    #network,
    #wireplumber,
    #cpu,
    #power-profiles-daemon,
    #battery {
      border-left: 1px solid ${palette.hex."border-strong"};
    }

    /* dictation indicator: muted when idle, alert while live/transcribing */
    #custom-voxtype {
      padding: 0 10px;
      color: ${palette.hex."text-muted"};
    }
    #custom-voxtype.recording {
      color: ${palette.hex."status-err"};
    }
    #custom-voxtype.transcribing {
      color: ${palette.hex.accent};
    }

    /* notification DND indicator: muted bell when idle, alert when silenced */
    #custom-dnd {
      padding: 0 10px;
      color: ${palette.hex."text-muted"};
    }
    #custom-dnd.dnd {
      color: ${palette.hex."status-err"};
    }
  '';

  terminal = lib.getExe pkgs.ghostty;
  hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  voxtype = lib.getExe pkgs.voxtype;
in
{
  config = lib.mkIf desktopEnabled {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = upstreamCss + marchyoCss;
      settings = [
        (
          {
            "reload_style_on_change" = true;
            layer = "top";
            position = "top";
            spacing = 0;
            height = 28;
            modules-left = [
              "custom/session"
              "hyprland/workspaces"
            ];
            modules-center = [ "clock" ];
            modules-right = [
              "group/tray-expander"
            ]
            ++ lib.optional voxtypeIndicator "custom/voxtype"
            ++ [
              "custom/dnd"
              "hyprland/language"
              "bluetooth"
              "network"
              "wireplumber"
              "cpu"
              "power-profiles-daemon"
              "battery"
            ];
            "custom/session" = {
              format = "marchyo";
              tooltip = false;
            };
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
              # No-op with a single layout; cycles every keyboard otherwise.
              on-click = "${hyprctl} switchxkblayout all next";
            };
            # Click actions that open a window launch it with an
            # org.omarchy.* --class so the floating-window tag rule in
            # modules/home/hyprland.nix applies (centered popup, not a tile) —
            # the same pattern as the SUPER+CTRL connectivity binds in
            # modules/home/omarchy-binds.nix.
            cpu = {
              interval = 5;
              format = "cpu {usage}%";
              on-click = "${terminal} --class=org.omarchy.btop -e ${lib.getExe pkgs.btop}";
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
              # Wi-Fi runs on NetworkManager's wpa_supplicant backend (see
              # modules/nixos/network.nix and docs/known-issues.md); nmtui
              # drives NetworkManager directly.
              on-click = "${terminal} --class=org.omarchy.nmtui -e ${lib.getExe' pkgs.networkmanager "nmtui"}";
            };
            battery = {
              interval = 5;
              format = "bat {capacity}%";
              format-charging = "chg {capacity}%";
              format-plugged = "pwr";
              format-full = "bat full";
              # Floating power/session menu (omarchy parity: battery click opens
              # the power menu). Bare name: the marchyo CLI is an HM-profile
              # script from modules/home/menus.nix, resolved via the session
              # PATH like marchyo-dnd-toggle below. Falls back to the launcher
              # when the menus feature is disabled.
              on-click =
                if menusEnabled then
                  "${terminal} --class=org.omarchy.terminal -e marchyo menu power"
                else
                  "vicinae toggle";
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
              on-click = "${terminal} --class=org.omarchy.bluetui -e ${lib.getExe pkgs.bluetui}";
            };
            wireplumber = {
              format = "vol {volume}%";
              format-muted = "vol mute";
              scroll-step = 5;
              # wiremix (not pavucontrol): the same floating mixer TUI the
              # SUPER+CTRL+A bind and the Setup menu open.
              on-click = "${terminal} --class=org.omarchy.wiremix -e ${lib.getExe pkgs.wiremix}";
              tooltip-format = "Playing at {volume}%";
              on-click-right = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
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
            # Notification do-not-disturb indicator. interval = "once" +
            # signal = 9: the script runs at startup and again on each
            # SIGRTMIN+9 (sent by marchyo-dnd-toggle), so state changes show
            # immediately without polling.
            "custom/dnd" = {
              exec = lib.getExe dndStatus;
              return-type = "json";
              interval = "once";
              signal = 9;
              on-click = "marchyo toggle notifications";
            };
            # No on-click: the module cycles power profiles natively on left
            # click (reverse on right click) and ignores on-click config —
            # waybar's PowerProfilesDaemon::handleToggle never delegates to
            # AModule.
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
          // lib.optionalAttrs voxtypeIndicator {
            # Defined (and the voxtype store path referenced) only when the
            # indicator is enabled. --follow streams state changes as JSON objects
            # that Waybar reads directly via return-type = "json"; the JSON's
            # class field (idle/recording/transcribing) drives the CSS above.
            "custom/voxtype" = {
              exec = "${voxtype} status --format json --follow --icon-theme nerd-font";
              return-type = "json";
              tooltip = true;
              # omarchy binds left/right-click to a model picker and a config
              # editor; both are meaningless here (the model comes from
              # marchyo.dictation.model and the config is a read-only /nix/store
              # symlink), so we map the clicks to the useful equivalents: toggle
              # recording, and open the floating status window (same command and
              # --class as the Super+Shift+H bind).
              on-click = "${voxtype} record toggle";
              on-click-right = "${terminal} --class=org.omarchy.voxtype -e ${voxtype} status --follow";
            };
          }
        )
      ];
    };

    # Override the systemd service to use full restart instead of SIGUSR2
    # This prevents the bug where SIGUSR2 causes multiple waybar instances
    systemd.user.services.waybar = {
      Service = {
        ExecReload = lib.mkForce [
          ""
          "${lib.getExe' pkgs.systemd "systemctl"} --user restart waybar.service"
        ];
      };
    };
  };
}
