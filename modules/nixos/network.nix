{ pkgs, ... }:
{
  networking = {
    networkmanager = {
      enable = true;
    };
  };
  environment.systemPackages = with pkgs; [
    # lazyssh # not available in 25.05
  ];
}
