{ lib, ... }:
{
  systemd.coredump = {
    enable = lib.mkDefault true;
    settings.Coredump = {
      Storage = lib.mkDefault "external";
      Compress = lib.mkDefault "yes";
      MaxUse = lib.mkDefault "2G";
      ProcessSizeMax = lib.mkDefault "8G";
    };
  };
}
