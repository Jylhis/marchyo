# Desktop profile - full-featured desktop environment
#
# Provides a complete desktop experience with Hyprland, productivity apps,
# and multimedia capabilities. Ideal for workstations and personal computers.

{ lib, ... }:

{
  imports = [
    ./base.nix
  ];

  # Enable desktop feature flag
  marchyo.desktop.enable = true;

  # Enable office applications
  marchyo.office.enable = lib.mkDefault true;

  # Enable media applications
  marchyo.media.enable = lib.mkDefault true;

  # Desktop-specific services
  services = {
    # Printing support
    printing.enable = lib.mkDefault true;

    # Bluetooth
    blueman.enable = lib.mkDefault true;

    # Location services for automatic timezone
    geoclue2.enable = lib.mkDefault true;

    # Thumbnail generation
    tumbler.enable = lib.mkDefault true;
  };

  # Graphics and hardware acceleration
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = lib.mkDefault true; # For some applications
    };

    # Bluetooth
    bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
    };
  };

  # Power management for laptops
  services.upower.enable = lib.mkDefault true;
  powerManagement = {
    enable = lib.mkDefault true;
    powertop.enable = lib.mkDefault false; # Can interfere with some hardware
  };

  # Sound

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = lib.mkDefault false;
  };

  # Fonts - extra fonts for desktop use
  fonts = {
    enableDefaultPackages = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Inter" ];
        serif = [ "Liberation Serif" ];
      };
    };
  };

  # XDG portal for desktop integration
  xdg.portal = {
    enable = true;
    extraPortals = [ ];
    config.common.default = "*";
  };

  # Enable GNOME Keyring for secret storage
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  # File indexing
  services.locate = {
    enable = lib.mkDefault true;
    # locate = lib.mkDefault "plocate";
    interval = "daily";
  };
}
