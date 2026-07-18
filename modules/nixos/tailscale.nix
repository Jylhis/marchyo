{ config, lib, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.services.tailscale.enable {
    services.tailscale.enable = lib.mkDefault true;

    networking.firewall = {
      # Trust traffic arriving over the tailnet interface.
      trustedInterfaces = [ "tailscale0" ];
      # Tailscale routes packets asymmetrically; strict reverse-path
      # filtering would drop them.
      checkReversePath = lib.mkDefault "loose";
      # Allow direct (non-DERP) WireGuard connections.
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
  };
}
