{ config, ... }:
{
  time.timeZone = config.marchyo.timezone;
  i18n = {
    inherit (config.marchyo) defaultLocale;
    supportedLocales = [ "all" ];
    # FIXME: ctrl+;
    #inputMethod = {
    #  enable = true;
    #  type = "fcitx5";
    #  fcitx5.addons = with pkgs; [
    #    fcitx5-mozc
    #    fcitx5-gtk
    #  ];
    #};
  };
}
