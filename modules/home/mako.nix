{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
in
{
  config = mkIf (cfg != null && cfg.enable && colors != null) {
    services.mako = {
      enable = true;

      # Base settings
      width = 420;
      height = 110;
      padding = "10";
      margin = "10";
      borderSize = 2;
      borderRadius = 0;
      anchor = "top-right";
      layer = "overlay";
      defaultTimeout = 5000;
      ignoreTimeout = false;
      maxVisible = 5;
      sort = "-time";
      groupBy = "app-name";
      actions = true;
      format = "<b>%s</b>\\n%b";
      markup = true;

      # Color configuration
      backgroundColor = "#${colors.base00}";
      textColor = "#${colors.base05}";
      borderColor = "#${colors.base0D}";
      progressColor = "over #${colors.base02}";

      extraConfig = ''
        [urgency=low]
        border-color=#${colors.base03}

        [urgency=normal]
        border-color=#${colors.base0D}

        [urgency=critical]
        border-color=#${colors.base08}
        text-color=#${colors.base08}
      '';
    };
  };
}
