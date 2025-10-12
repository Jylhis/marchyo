# Base profile - minimal common configuration shared by all profiles
#
# This profile provides the absolute minimum configuration that should be
# present on all Marchyo systems, regardless of their specific purpose.

{ lib, ... }:

{
  # Nix settings
  nix = {
    settings = {
      # Enable flakes and nix-command
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Optimize store automatically
      auto-optimise-store = true;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Timezone (can be overridden by marchyo.timezone)
  time.timeZone = lib.mkDefault "Europe/Zurich";

  # Locale (can be overridden by marchyo.defaultLocale)
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Console configuration
  console = {
    font = lib.mkDefault "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
  };

  # Basic networking
  networking = {
    # Enable NetworkManager by default
    networkmanager.enable = lib.mkDefault true;

    # Firewall enabled by default
    firewall.enable = lib.mkDefault true;
  };

  # Basic security
  security = {
    # Disable sudo password for wheel group (can be overridden)
    sudo.wheelNeedsPassword = lib.mkDefault false;

    # Polkit for privilege escalation
    polkit.enable = true;
  };

  # System packages that should always be present
  environment.systemPackages = [ ];

  # State version - should match NixOS version
  # This is a sensible default, but should be set explicitly
  system.stateVersion = lib.mkDefault "25.11";
}
