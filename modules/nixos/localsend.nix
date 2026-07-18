# LocalSend: LAN file sharing shipped with the desktop.
# Installs the app and opens its discovery/transfer port, gated on the
# marchyo.services.localsend.enable sub-toggle (dictation UI-suboption pattern:
# on by default, only active when the desktop is enabled).
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
