{ lib, ... }:
{
  # mDNS / DNS-SD: resolve <host>.local and discover LAN services (printers,
  # LocalSend, Chromecast, SSH-by-hostname). All mkDefault so a host can opt out.
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
