{ lib, config, ... }:
let
  cfg = config.marchyo;
in
{
  # Stateful nftables-based firewall with a deny-inbound default
  # (established/related traffic is always allowed). The default follows
  # marchyo.security.firewall.enable, so turning that option off is a real
  # off-by-default switch (NixOS itself would otherwise leave the firewall
  # on); mkDefault keeps networking.firewall.enable overridable in either
  # direction. Service modules register their ports independently and only
  # matter on hosts where the firewall ends up enabled: avahi opens its own
  # mDNS port via services.avahi openFirewall, and LocalSend's port opens via
  # modules/nixos/localsend.nix.
  networking.firewall.enable = lib.mkDefault cfg.security.firewall.enable;
}
