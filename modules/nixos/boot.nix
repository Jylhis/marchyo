{ lib, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 5;
  };
}
