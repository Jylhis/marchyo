{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkMerge;
  useWofi = if osConfig ? marchyo then osConfig.marchyo.desktop.useWofi or false else false;

  # Helper to format hex color with # prefix

  # Generate Vicinae theme as Nix attribute set
in
{
  # Enable vicinae when wofi is not explicitly requested
  config = mkIf (!useWofi) {
    services.vicinae = {
      enable = true;
      settings = mkMerge [
        {
          # Configure window appearance
          window = {
            opacity = 0.95;
            rounding = 0;
          };

          # Font configuration
          font = {
            size = 18;
          };
        }

      ];
    };
  };
}
