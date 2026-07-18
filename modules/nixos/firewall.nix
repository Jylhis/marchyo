{ lib, ... }:
{
  # Enable the stateful nftables-based firewall with a deny-inbound default
  # (established/related traffic is always allowed). mkDefault so a host can
  # disable or extend it. avahi opens its own mDNS port via services.avahi
  # openFirewall; LocalSend's port opens via modules/nixos/localsend.nix.
  networking.firewall.enable = lib.mkDefault true;
}
