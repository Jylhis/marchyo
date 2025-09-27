{ pkgs, ... }:
{
  hardware = {
    enableAllFirmware = true;
  };

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  environment.systemPackages = [ pkgs.bluetui ];

  # Power management
  services = {
    power-profiles-daemon.enable = true;
    upower.enable = true;
    thermald.enable = true;
  };

}
