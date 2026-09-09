# Global (headless-safe) firmware/thermal/power; bluetooth is desktop-gated.
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

  # Desktop-only, and the sole owner of hardware.bluetooth.enable —
  # modules/nixos/desktop-config.nix deliberately does not set it.
  hardware.bluetooth = lib.mkIf config.marchyo.desktop.enable {
    enable = lib.mkDefault true;
    powerOnBoot = lib.mkDefault true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  environment.systemPackages = lib.mkIf config.marchyo.desktop.enable [ pkgs.bluetui ];

  services = {
    power-profiles-daemon.enable = lib.mkDefault true;
    upower.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault (pkgs.stdenv.hostPlatform.system == "x86_64-linux");
  };

}
