{ lib, config, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.autoTimezone.enable {
    services.automatic-timezoned.enable = lib.mkDefault true;
    services.geoclue2.enable = lib.mkDefault true;

    warnings = lib.optional (cfg.timezone != "Europe/Zurich") ''
      marchyo.autoTimezone.enable is on, so marchyo.timezone ("${cfg.timezone}")
      is ignored — the timezone is set automatically from your location.
    '';
  };
}
