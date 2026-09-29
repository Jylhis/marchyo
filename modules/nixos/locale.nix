{ lib, config, ... }:
{
  time.timeZone = lib.mkDefault config.marchyo.timezone;
  i18n = {
    defaultLocale = lib.mkDefault config.marchyo.defaultLocale;
    supportedLocales = [ "all" ];
  };
}
