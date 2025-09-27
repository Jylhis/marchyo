{ lib, ... }:
{
  time.timeZone = lib.mkDefault "Europe/Zurich"; # TODO: options
  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8"; # TODO: option
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
