# Gaming Desktop Configuration Example
#
# This configuration optimizes NixOS for gaming with:
# - Hyprland desktop environment
# - Steam with Proton
# - Gaming optimizations (kernel, performance)
# - Media applications
#
# Usage:
#   1. Copy to your configuration directory
#   2. Adjust hostname, timezone, and user details
#   3. Add hardware-configuration.nix
#   4. Deploy with nixos-rebuild

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Add Marchyo modules here when using as flake input
  ];

  # System Configuration
  networking.hostName = "gaming-rig";

  # Marchyo Configuration
  marchyo = {
    desktop.enable = true;      # Hyprland with optimizations
    development.enable = false; # Not needed for gaming-only system
    media.enable = true;        # MPV, media players
    office.enable = false;

    timezone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";

    users.gamer = {
      enable = true;
      fullname = "Gamer Name";
      email = "gamer@example.com";
    };
  };

  # User Configuration
  users.users.gamer = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "gamemode"  # For gamemode optimizations
    ];
  };

  # Gaming-Specific Configuration

  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    gamescopeSession.enable = true;
  };

  # GameMode for performance optimizations
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  # Gaming packages
  environment.systemPackages = with pkgs; [
    # Game launchers
    lutris
    heroic
    bottles

    # Emulators
    # retroarch
    # dolphin-emu

    # Game tools
    mangohud  # FPS overlay
    goverlay  # MangoHud configurator
    protonup-qt  # Proton-GE manager

    # Voice chat
    discord
    # mumble

    # Performance monitoring
    nvtopPackages.full  # GPU monitoring
  ];

  # Graphics optimizations
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Required for 32-bit games
  };

  # Kernel optimizations for gaming
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    # Already set in marchyo's performance module:
    # "mitigations=off"

    # Additional gaming optimizations
    "split_lock_detect=off"
  ];

  # Improve performance
  powerManagement.cpuFreqGovernor = "performance";

  # Audio latency optimization
  services.pipewire = {
    # Already enabled by marchyo
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 32;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 32;
      };
    };
  };

  # Network optimization for gaming
  services.mullvad-vpn.enable = false;  # Enable if using Mullvad VPN
  networking.firewall = {
    enable = true;
    # Open ports for game-specific needs
    # allowedTCPPorts = [ ];
    # allowedUDPPorts = [ ];
  };

  # Home Manager Configuration
  home-manager.users.gamer = {
    imports = [
      # Marchyo home modules imported via flake
    ];

    home.stateVersion = "24.11";

    # Gaming shortcuts in shell
    programs.bash.shellAliases = {
      steam-native = "steam -nativevulkan";
      gamemode-on = "gamemoded -r";
    };

    # Additional packages
    home.packages = with pkgs; [
      # Screenshot tools (wayland)
      # Already included in Hyprland module: grim, slurp

      # Game recording
      obs-studio
      # wf-recorder  # Already in Hyprland module

      # Performance tools
      piper  # Gaming mouse configuration
    ];
  };

  # Disable power saving features for gaming performance
  # (Override marchyo's powersave module if it's enabled)
  networking.networkmanager.wifi.powersave = lib.mkForce false;
  services.tlp.enable = lib.mkForce false;

  system.stateVersion = "24.11";
}
