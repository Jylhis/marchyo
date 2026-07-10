{ lib, config, ... }:
let
  cfg = config.marchyo;
in
{
  # Enable the stateful nftables-based firewall with a deny-inbound default
  # (established/related traffic is always allowed). mkDefault so a host can
  # disable or extend it. avahi opens its own mDNS port via services.avahi
  # openFirewall.
  networking.firewall = {
    enable = lib.mkDefault true;

    # LocalSend (shipped on the desktop) needs its port reachable on the LAN.
    allowedTCPPorts = lib.mkIf cfg.desktop.enable [ 53317 ];
    allowedUDPPorts = lib.mkIf cfg.desktop.enable [ 53317 ];
  };
}
