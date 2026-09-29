# Global (headless-safe): NetworkManager is marchyo's default network stack on
# servers and laptops alike. mkDefault so a host can swap in
# systemd-networkd without lib.mkForce.
{ lib, ... }:
{
  networking = {
    networkmanager = {
      enable = lib.mkDefault true;
      # Do NOT set wifi.backend = "iwd": iwd 3.12 segfaults during roaming
      # (network_info_get_roam_frequencies via an 802.11k neighbor report) in
      # multi-AP environments, dropping the connection repeatedly. See
      # docs/known-issues.md ("iwd backend Wi-Fi crashes").
    };
  };
}
