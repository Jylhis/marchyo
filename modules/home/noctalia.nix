{
  lib,
  pkgs,
  noctalia,
  ...
}:
{
  config = {
    programs.noctalia-shell = {
      enable = lib.mkDefault true;
      systemd.enable = true;
      package = noctalia.packages.${pkgs.system}.default.override {
        calendarSupport = true;
      };
    };
  };
}
