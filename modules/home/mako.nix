{
  lib,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf mkMerge;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
in
{
  config = {
    services.mako = {
      enable = true;

      settings = mkMerge [
        {
          # Base settings
          width = 420;
          height = 110;
          padding = "10";
          margin = "10";
          border-size = 2;
          border-radius = 0;
          anchor = "top-right";
          layer = "overlay";
          default-timeout = 5000;
          ignore-timeout = false;
          max-visible = 5;
          sort = "-time";
          group-by = "app-name";
          actions = true;
          format = "<b>%s</b>\\n%b";
          markup = true;
        }
        (mkIf (cfg != null && cfg.enable && colors != null) {
          # Color configuration
          background-color = "#${colors.base00}";
          text-color = "#${colors.base05}";
          border-color = "#${colors.base0D}";
          progress-color = "over #${colors.base02}";

          urgency-low = {
            border-color = "#${colors.base03}";
          };

          urgency-normal = {
            border-color = "#${colors.base0D}";
          };

          urgency-critical = {
            border-color = "#${colors.base08}";
            text-color = "#${colors.base08}";
          };
        })
      ];
    };
  };
}
