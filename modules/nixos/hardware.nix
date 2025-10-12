{ pkgs, lib, ... }:
{
  hardware = {
    # Use lib.mkDefault so tests can override this
    enableRedistributableFirmware = lib.mkDefault true;
  };

  # Thunderbolt
  services.hardware.bolt.enable = lib.mkDefault true;

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
    power-profiles-daemon.enable = lib.mkDefault true;
    upower.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault (pkgs.stdenv.hostPlatform.system == "x86_64-linux");
  };

}
