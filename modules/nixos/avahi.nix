{ lib, ... }:
{
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    settings.publish = {
      disable-publishing = lib.mkDefault false;
      publish-addresses = lib.mkDefault true;
      publish-workstation = lib.mkDefault true;
    };
  };
}
