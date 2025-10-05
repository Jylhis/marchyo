# Gaming profile - optimized for gaming performance
#
# Extends the desktop profile with gaming-specific optimizations including
# Steam, Gamemode, low-latency audio, and performance tuning. Ideal for
# gaming workstations and entertainment systems.

{ lib, pkgs, ... }:

{
  imports = [
    ./desktop.nix
  ];

  # Enable media applications for gaming
  marchyo.media.enable = true;

  # Steam configuration
  programs.steam = {
    enable = true;

    # Enable Steam Remote Play through firewall
    remotePlay.openFirewall = true;

    # Enable gamescope session for better gaming experience
    # Gamescope provides a compositor optimized for gaming with features like
    # FSR upscaling, frame limiting, and better performance
    gamescopeSession.enable = true;
  };

  # Gamemode for automatic performance optimization
  # Gamemode temporarily applies system optimizations when games are running
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        # Increase process priority for games (lower nice value = higher priority)
        renice = 10;
      };
    };
  };

  # Low-latency audio configuration for gaming
  # Reduced buffer sizes minimize audio delay in games
  services.pipewire.extraConfig.pipewire = {
    "10-gaming-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256; # Lower quantum for reduced latency
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 512;
      };
    };
  };

  # Use latest kernel for best hardware support and performance
  # Latest kernel includes newest drivers, optimizations, and game compatibility fixes
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Performance-oriented CPU governor
  # "performance" keeps CPU at maximum frequency for best gaming performance
  # Note: This increases power consumption, consider "schedutil" for laptops
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # Enable 32-bit graphics support
  # Required for many games and Windows compatibility layers
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Gaming system optimizations
  boot.kernel.sysctl = {
    # Increase virtual memory map count limit
    # Many games (especially Source engine and Unity games) require higher limits
    # to avoid "out of memory" errors with many assets
    "vm.max_map_count" = lib.mkDefault 2147483642;
  };

  # Gaming-related packages
  environment.systemPackages = with pkgs; [
    # MangoHud - in-game overlay for FPS, CPU/GPU stats, temps
    mangohud

    # Steam utilities for running non-Steam apps in Steam environment
    steam-run

    # Wine - Windows compatibility layer for running Windows games
    wine
    winetricks # Wine configuration and Windows runtime installer

    # Lutris - gaming platform supporting multiple game sources
    lutris
  ];
}
