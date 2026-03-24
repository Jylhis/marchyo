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

    # dconf is required for GTK apps to read settings (icon theme, font, etc.)
    programs.dconf.enable = lib.mkDefault true;

    # XDG icon and MIME infrastructure for proper icon/file-type discovery
    xdg.icons.enable = lib.mkDefault true;
    xdg.mime.enable = lib.mkDefault true;

    # Desktop services
    services = {
      printing.enable = lib.mkDefault true;
      blueman.enable = lib.mkDefault true;
      geoclue2.enable = lib.mkDefault true;
      tumbler.enable = lib.mkDefault true;
      upower.enable = lib.mkDefault true;
      udisks2.enable = lib.mkDefault true;
      locate = {
        enable = lib.mkDefault true;
        interval = "daily";
      };
      gnome.gnome-keyring.enable = lib.mkDefault true;
      gvfs.enable = lib.mkDefault true;
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
      jack.enable = lib.mkDefault true;
      wireplumber.enable = true;
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

    # Nautilus extension discovery (sushi previews, etc.)
    environment.sessionVariables.NAUTILUS_4_EXTENSION_DIR = "${config.system.path}/lib/nautilus/extensions-4";

    # xdg-user-dirs-gtk generates GTK bookmarks for sidebar folders (Documents, Downloads, etc.)
    environment.systemPackages = [ pkgs.xdg-user-dirs-gtk ];

    # XDG portal
    xdg.portal = {
      enable = true;
      extraPortals = [ ];
      config.common.default = lib.mkDefault "*";
    };
  };
}
