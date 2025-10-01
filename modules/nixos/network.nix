{ pkgs, ... }:
{
  # services.resolved.enable = true;
  networking = {
    wireless = {
      iwd = {
        enable = true;
        settings = {
          AutoConnect = true;
        };
      };
    };
    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
  };
  environment.systemPackages = with pkgs; [
    impala # TUI for managing your Wi-Fi connection, NOTE: doesnt support network manager
    # lazyssh # not available in 25.05
  ];
}
