{
  lib,
  osConfig,
  ...
}:
let
  locale = osConfig.marchyo.defaultLocale;
in
{
  home.language = lib.mkDefault {
    base = locale;
    address = locale;
    collate = locale;
    ctype = locale;
    measurement = locale;
    messages = locale;
    monetary = locale;
    name = locale;
    numeric = locale;
    paper = locale;
    telephone = locale;
    time = locale;
  };
}
