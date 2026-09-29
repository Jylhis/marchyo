{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.services.localsend.enable) {
    environment.systemPackages = [ pkgs.localsend ];

    # LocalSend needs its port reachable on the LAN for discovery + transfers.
    networking.firewall = {
      allowedTCPPorts = [ 53317 ];
      allowedUDPPorts = [ 53317 ];
    };
  };
}
