# Global (headless-safe): NetworkManager is marchyo's default network stack on
# servers and laptops alike. mkDefault so a host can swap in
# systemd-networkd without lib.mkForce.
{ config, lib, ... }:
let
  check = config.marchyo.network.connectivityCheck;
in
{
  networking = {
    networkmanager = {
      enable = lib.mkDefault true;
      # Do NOT set wifi.backend = "iwd": iwd 3.12 segfaults during roaming
      # (network_info_get_roam_frequencies via an 802.11k neighbor report) in
      # multi-AP environments, dropping the connection repeatedly. See
      # docs/gotchas.md ("iwd backend Wi-Fi crashes").
      settings.connectivity = lib.mkIf check.enable {
        inherit (check) uri response;
        interval = toString check.interval;
      };
    };
  };
}
