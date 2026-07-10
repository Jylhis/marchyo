{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo = {
    timezone = mkOption {
      type = types.str;
      default = "Europe/Zurich";
      example = "America/New_York";
      description = "System timezone";
    };

    defaultLocale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      example = "de_DE.UTF-8";
      description = "System default locale";
    };

    autoTimezone.enable = lib.mkEnableOption ''
      automatic timezone updates from your location (services.automatic-timezoned
      via geoclue2). Opt-in and off by default. When enabled it overrides the
      static marchyo.timezone; a warning is emitted if marchyo.timezone was also
      changed from its default'';
  };
}
