{ lib, config, ... }:
let
  cfg = config.marchyo;
in
{
  # Following the enable flag makes "off" a real off-by-default switch (NixOS
  # otherwise leaves the firewall on); mkDefault keeps it overridable either way.
  # Service modules (avahi, localsend) open their own ports independently.
  networking.firewall.enable = lib.mkDefault cfg.security.firewall.enable;
}
