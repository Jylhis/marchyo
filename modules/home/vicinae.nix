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
  variant = if config ? colorScheme then config.colorScheme.variant else "dark";
in
{
  # Enable vicinae by default when theming is enabled, unless wofi is explicitly requested
  config = mkIf (cfg != null && cfg.enable && colors != null && !useWofi) {
    services.vicinae = {
      enable = true;
      autoStart = true;
      settings = {
        # Configure window appearance
        window = {
          opacity = 0.95;
          rounding = 0;
        };

        # Use appropriate built-in theme based on variant
        theme = {
          name = if variant == "light" then "vicinae-light" else "vicinae-dark";
        };

        # Font configuration
        font = {
          size = 18;
        };
      };
    };
  };
}
