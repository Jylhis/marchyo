{ pkgs, ... }:
{
  services.resolved.enable = true;
  networking = {
    networkmanager.enable = true;
  };
  environment.systemPackages = with pkgs; [
    impala # TUI for managing your Wi-Fi connection, NOTE: doesnt support network manager
    lazyssh
  ];
}
