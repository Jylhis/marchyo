# Global (headless-safe): polkit is needed by system services, not just the
# desktop.
{ config, lib, ... }:
{
  security = {
    polkit = {
      enable = lib.mkDefault true;
    };

    sudo.extraConfig = ''
      Defaults timestamp_timeout=${toString config.marchyo.security.sudo.timestampTimeout}
    '';
  };

  # Answer ARP only for the interface's own address, and announce from it.
  # Otherwise, with a dock's Ethernet and Wi-Fi on one network, Wi-Fi answers
  # for the wired address and NetworkManager takes the wired routes down.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = lib.mkDefault 1;
    "net.ipv4.conf.default.arp_ignore" = lib.mkDefault 1;
    "net.ipv4.conf.all.arp_announce" = lib.mkDefault 2;
    "net.ipv4.conf.default.arp_announce" = lib.mkDefault 2;
  };
}
