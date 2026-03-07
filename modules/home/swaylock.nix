{
  lib,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;
in
{
  config = {
    programs.swaylock = {
      enable = true;
      settings = mkIf (cfg != null && cfg.enable) {
        show-failed-attempts = true;
        ignore-empty-password = true;
        indicator-radius = 100;
        indicator-thickness = 4;
        font = "CaskaydiaMono Nerd Font";
        font-size = 32;
      };
    };
  };
}
