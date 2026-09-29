{
  lib,
  osConfig ? { },
  ...
}:
let
  hasMarchyo = osConfig ? marchyo;
  locale = if hasMarchyo then osConfig.marchyo.defaultLocale else "en_US.UTF-8";
in
{
  config = lib.mkIf hasMarchyo {
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
  };
}
