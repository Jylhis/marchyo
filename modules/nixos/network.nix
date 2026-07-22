{ lib, pkgs, ... }:
{
  networking = {
    networkmanager = {
      enable = true;
      # impala (the Wi-Fi TUI behind the waybar network segment, the
      # SUPER+CTRL+W bind and the system menu) only speaks iwd. Run
      # NetworkManager with the iwd Wi-Fi backend (this auto-enables
      # networking.wireless.iwd) so those surfaces actually control the
      # active stack — NetworkManager still owns ethernet/VPN.
      wifi.backend = lib.mkDefault "iwd";
    };
  };
  environment.systemPackages = with pkgs; [
    impala # TUI for managing your Wi-Fi connection (iwd frontend)
    # lazyssh # not available in 25.05
  ];
}
