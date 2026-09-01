{
  pkgs,
  lib,
  config,
  ...
}:
{
  hardware = {
    # Use lib.mkDefault so tests can override this
    enableRedistributableFirmware = lib.mkDefault true;

    # Logitech wireless devices (udev rules), opt-in.
    logitech.wireless.enable = lib.mkIf config.marchyo.hardware.logitech.enable true;
  };

  # Solaar GUI (renamed from hardware.logitech.wireless.enableGraphical).
  programs.solaar.enable = lib.mkIf config.marchyo.hardware.logitech.enable true;

  # Thunderbolt
  services.hardware.bolt.enable = lib.mkDefault true;

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

  services = {
    power-profiles-daemon.enable = lib.mkDefault true;
    upower.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault (pkgs.stdenv.hostPlatform.system == "x86_64-linux");
  };

}
