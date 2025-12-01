# Desktop configuration module
# Automatically enables desktop-related services and settings when marchyo.desktop.enable is true
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.desktop.enable {
    # Automatically enable office and media apps by default when desktop is enabled
    marchyo.office.enable = lib.mkDefault true;
    marchyo.media.enable = lib.mkDefault true;

    # Desktop services
    services = {
      printing.enable = lib.mkDefault true;
      blueman.enable = lib.mkDefault true;
      geoclue2.enable = lib.mkDefault true;
      tumbler.enable = lib.mkDefault true;
      upower.enable = lib.mkDefault true;
      locate = {
        enable = lib.mkDefault true;
        interval = "daily";
      };
      gnome.gnome-keyring.enable = lib.mkDefault true;
    };

    # Hardware
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = lib.mkDefault (pkgs.stdenv.hostPlatform.system == "x86_64-linux");
      };
      bluetooth = {
        enable = lib.mkDefault true;
        powerOnBoot = lib.mkDefault true;
      };
    };

    # Power management
    powerManagement = {
      enable = lib.mkDefault true;
      powertop.enable = lib.mkDefault false;
    };

    # Audio
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = lib.mkDefault false;
    };

    # Fonts
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

    # XDG portal
    xdg.portal = {
      enable = true;
      extraPortals = [ ];
      config.common.default = "*";
    };
  };
}
