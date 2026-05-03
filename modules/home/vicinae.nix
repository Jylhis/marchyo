{
  lib,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf mkMerge;
  useWofi = if osConfig ? marchyo then osConfig.marchyo.desktop.useWofi or false else false;
in
{
  # Enable vicinae when wofi is not explicitly requested
  config = mkIf (!useWofi) {
    services.vicinae = {
      enable = true;
      settings = mkMerge [
        {
          # Jylhis Design System — no transparency, paper metaphor
          window = {
            opacity = 1.0;
            rounding = 4;
          };

          font = {
            size = 14;
          };
        }

      ];
    };
  };
}
