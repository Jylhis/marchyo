_: {
  networking = {
    networkmanager = {
      enable = true;
      # Wi-Fi runs on NetworkManager's default wpa_supplicant backend.
      # We deliberately do NOT set wifi.backend = "iwd": iwd 3.12 segfaults
      # during roaming (network_info_get_roam_frequencies via an 802.11k
      # neighbor report) in multi-AP environments, which repeatedly drops the
      # connection. See docs/known-issues.md ("iwd backend Wi-Fi crashes").
      # The Wi-Fi TUI surfaces (waybar segment, SUPER+CTRL+W, system menu) use
      # nmtui (shipped with the networkmanager package), which drives
      # NetworkManager directly.
    };
  };
}
