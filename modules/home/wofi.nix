{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  useWofi = if osConfig ? marchyo then osConfig.marchyo.desktop.useWofi or false else false;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  hex = color: "#${color}";

  # Default style without theme colors
  defaultStyle = ''
    * {
      font-family: 'CaskaydiaMono Nerd Font', monospace;
      font-size: 18px;
    }

    window {
      margin: 0px;
      padding: 20px;
      opacity: 0.95;
    }

    #inner-box {
      margin: 0;
      padding: 0;
      border: none;
    }

    #outer-box {
      margin: 0;
      padding: 20px;
      border: none;
    }

    #scroll {
      margin: 0;
      padding: 0;
      border: none;
    }

    #input {
      margin: 0;
      padding: 10px;
      border: none;
    }

    #input:focus {
      outline: none;
      box-shadow: none;
    }

    #text {
      margin: 5px;
      border: none;
    }

    #entry:selected {
      outline: none;
      border: none;
    }

    #entry image {
      -gtk-icon-transform: scale(0.7);
    }
  '';

  # Themed style
  themedStyle = ''
    * {
      font-family: 'CaskaydiaMono Nerd Font', monospace;
      font-size: 18px;
    }

    window {
      margin: 0px;
      padding: 20px;
      background-color: ${hex colors.base00};
      color: ${hex colors.base05};
      opacity: 0.95;
    }

    #inner-box {
      margin: 0;
      padding: 0;
      border: none;
    }

    #outer-box {
      margin: 0;
      padding: 20px;
      border: none;
    }

    #scroll {
      margin: 0;
      padding: 0;
      border: none;
    }

    #input {
      margin: 0;
      padding: 10px;
      border: none;
      background-color: ${hex colors.base01};
      color: ${hex colors.base05};
    }

    #input:focus {
      outline: none;
      box-shadow: none;
      border: 1px solid ${hex colors.base0D};
    }

    #text {
      margin: 5px;
      border: none;
      color: ${hex colors.base05};
    }

    #entry:selected {
      background-color: ${hex colors.base01};
      color: ${hex colors.base0D};
      outline: none;
      border: none;
    }

    #entry image {
      -gtk-icon-transform: scale(0.7);
    }
  '';
in
{
  # Enable wofi when explicitly requested via marchyo.desktop.useWofi = true
  config = mkIf useWofi {
    programs.wofi = {
      enable = true;
      settings = {
        width = 600;
        height = 350;
        location = "center";
        show = "drun";
        prompt = "Search...";
        filter_rate = 100;
        allow_markup = true;
        no_actions = true;
        halign = "fill";
        orientation = "vertical";
        content_halign = "fill";
        insensitive = true;
        allow_images = true;
        image_size = 40;
        gtk_dark = true;
      };
      style = if (cfg != null && cfg.enable && colors != null) then themedStyle else defaultStyle;
    };
  };
}
