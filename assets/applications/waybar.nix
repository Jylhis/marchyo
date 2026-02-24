{ colors }:
''
  /* Restored colors using Stylix */
  * {
      border: none;
      border-radius: 0;
      min-height: 0;
      font-family: CaskaydiaMono Nerd Font;
      font-size: 14px;
      color: ${colors.base05};
  }

  window#waybar {
      background-color: ${colors.base00};
      border-bottom: 2px solid ${colors.base0C};
      color: ${colors.base05};
      transition-property: background-color;
      transition-duration: .5s;
  }

  #workspaces button {
      padding: 0 5px;
      background-color: transparent;
      color: ${colors.base05};
      border-bottom: 3px solid transparent;
  }

  #workspaces button:hover {
      background: ${colors.base01};
      box-shadow: inherit;
      border-bottom: 3px solid ${colors.base05};
  }

  #workspaces button.active {
      background-color: ${colors.base02};
      border-bottom: 3px solid ${colors.base0D};
  }

  #workspaces button.urgent {
      background-color: ${colors.base08};
  }

  #clock,
  #battery,
  #cpu,
  #memory,
  #disk,
  #temperature,
  #backlight,
  #network,
  #pulseaudio,
  #wireplumber,
  #custom-media,
  #tray,
  #mode,
  #idle_inhibitor,
  #scratchpad,
  #power-profiles-daemon,
  #mpd {
      padding: 0 10px;
      color: ${colors.base05};
      background-color: ${colors.base01};
      margin: 4px 2px;
  }

  #window,
  #workspaces {
      margin: 0 4px;
  }

  /* Specific tweaks from original file */
  #tray,
  #power-profiles-daemon,
  #custom-screenrecording-indicator,
  #custom-update {
      padding: 0 5px;
      min-width: 12px;
  }

  #custom-expand-icon {
      margin-right: 7px;
  }

  #custom-update {
      font-size: 10px;
  }
''
