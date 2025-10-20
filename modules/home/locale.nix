{ lib, osConfig, ... }:
{
  i18n = {
    # FIXME: ctrl+;
    #inputMethod = {
    #  enable = true;
    #type = "fcitx5";
    #fcitx5.addons = with pkgs; [
    #  fcitx5-mozc
    #  fcitx5-gtk
    #];
    # };
  };

  # Home Manager language configuration - use osConfig to get marchyo settings
  home.language = lib.mkDefault {
    base = osConfig.marchyo.defaultLocale;
    address = osConfig.marchyo.defaultLocale;
    collate = osConfig.marchyo.defaultLocale;
    ctype = osConfig.marchyo.defaultLocale;
    measurement = osConfig.marchyo.defaultLocale;
    messages = osConfig.marchyo.defaultLocale;
    monetary = osConfig.marchyo.defaultLocale;
    name = osConfig.marchyo.defaultLocale;
    numeric = osConfig.marchyo.defaultLocale;
    paper = osConfig.marchyo.defaultLocale;
    telephone = osConfig.marchyo.defaultLocale;
    time = osConfig.marchyo.defaultLocale;
  };
}
