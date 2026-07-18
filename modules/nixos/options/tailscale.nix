{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.services.tailscale = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable the Tailscale mesh VPN daemon and open the firewall for its traffic.";
    };
  };
}
