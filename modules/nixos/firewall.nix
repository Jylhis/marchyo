{ lib, config, ... }:
{
  options.marchyo.firewall = {
    enable = lib.mkEnableOption "firewall configuration" // {
      default = true;
    };

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "List of TCP ports to allow through the firewall";
      example = [
        80
        443
        22
      ];
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "List of UDP ports to allow through the firewall";
      example = [ 53 ];
    };

    allowPing = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to respond to ping requests";
    };
  };

  config = lib.mkIf config.marchyo.firewall.enable {
    networking.firewall = {
      enable = true;

      # Default policy: deny incoming, allow outgoing
      inherit (config.marchyo.firewall) allowedTCPPorts;
      inherit (config.marchyo.firewall) allowedUDPPorts;

      # Allow ping responses
      inherit (config.marchyo.firewall) allowPing;

      # Log refused connections for debugging
      logRefusedConnections = lib.mkDefault false;

      # Log refused packets (more verbose)
      logRefusedPackets = lib.mkDefault false;

      # Reject packets instead of dropping (better for debugging)
      rejectPackets = lib.mkDefault false;
    };

    # Ensure nftables is used (modern replacement for iptables)
    networking.nftables.enable = lib.mkDefault true;
  };
}
