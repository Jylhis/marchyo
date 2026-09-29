{ lib, ... }:
{
  # All mkDefault so a host can opt out.
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    publish = {
      enable = lib.mkDefault true;
      addresses = lib.mkDefault true;
      workstation = lib.mkDefault true;
    };
  };
}
