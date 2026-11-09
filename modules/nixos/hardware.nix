{
  pkgs,
  lib,
  config,
  ...
}:
{
  hardware = {
    # mkDefault so tests can override this.
    enableRedistributableFirmware = lib.mkDefault true;

    logitech.wireless.enable = lib.mkIf config.marchyo.hardware.logitech.enable true;
  };

  programs.solaar.enable = lib.mkIf config.marchyo.hardware.logitech.enable true;

  services.hardware.bolt.enable = lib.mkDefault true;

  # Sole owner of hardware.bluetooth.enable: modules/nixos/desktop-config.nix
  # deliberately does not set it.
  hardware.bluetooth = lib.mkIf config.marchyo.desktop.enable {
    enable = lib.mkDefault true;
    powerOnBoot = lib.mkDefault true;
    settings = {
      General = {
        Experimental = true;
        # ISO sockets for LE Audio BAP are a kernel experiment; Experimental only covers D-Bus.
        KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
      };
    };
  };
  environment.systemPackages = lib.mkIf config.marchyo.desktop.enable [ pkgs.bluetui ];

  services = {
    power-profiles-daemon.enable = lib.mkDefault true;
    upower.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault config.hardware.cpu.intel.updateMicrocode;
  };

}
