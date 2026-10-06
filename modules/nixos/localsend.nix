{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.services.localsend.enable) {
    programs.localsend = {
      enable = true;
      inherit (cfg.services.localsend) openFirewall;
    };
  };
}
