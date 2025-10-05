{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
    mkEnableOption
    mkOption
    types
    ;
  cfg = config.marchyo.gaming;
in
{
  options.marchyo.gaming = {
    enable = mkEnableOption "gaming configuration" // {
      default = false;
      description = ''
        Enable gaming-specific system configuration.
        Includes Steam, GameMode, GameScope, and performance optimizations.
      '';
    };

    usePerformanceGovernor = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Set CPU governor to 'performance' mode for maximum performance.
        This increases power consumption but may improve gaming performance.
      '';
    };

    useLatestKernel = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Use the latest mainline Linux kernel instead of the default.
        May improve hardware support and performance for newer games.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Steam with optimizations
    programs.steam = {
      enable = true;
      # Enable GameScope session for better performance
      gamescopeSession.enable = mkDefault true;
      # Enable Steam Remote Play
      remotePlay.openFirewall = mkDefault true;
      # Enable local network game transfers
      localNetworkGameTransfers.openFirewall = mkDefault true;
    };

    # GameMode for automatic game optimizations
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          # Increase niceness priority for games
          renice = mkDefault 10;
          # Increase I/O priority for games
          ioprio = mkDefault 0;
        };
        # GPU optimizations
        gpu = {
          # Apply GPU performance mode when gaming
          apply_gpu_optimisations = mkDefault "accept-responsibility";
          # Keep GPU in high performance mode
          gpu_device = mkDefault 0;
        };
        # Custom scripts can be added here
        custom = {
          # Start script runs when game starts
          start = mkDefault "";
          # End script runs when game exits
          end = mkDefault "";
        };
      };
    };

    # Enable 32-bit graphics support for games
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Gaming packages
    environment.systemPackages = with pkgs; [
      # Performance overlay and monitoring
      mangohud

      # Run Steam games and other executables
      steam-run

      # Windows compatibility layer
      wine
      winetricks

      # Multi-platform game launcher
      lutris

      # GameScope compositor for better game performance
      gamescope
    ];

    # Kernel optimizations for gaming
    boot.kernelParams = [
      # Increase vm.max_map_count for games that require many memory maps
      # (e.g., Star Citizen, some Proton games)
      "vm.max_map_count=2147483642"
    ];

    # Use latest kernel if requested
    boot.kernelPackages = mkIf cfg.useLatestKernel (mkDefault pkgs.linuxPackages_latest);

    # CPU governor for performance
    powerManagement.cpuFreqGovernor = mkIf cfg.usePerformanceGovernor (mkDefault "performance");

    # Low-latency audio configuration for gaming
    # PipeWire quantum settings reduce audio latency
    services.pipewire.extraConfig.pipewire = {
      "99-gaming-lowlatency" = {
        "context.properties" = {
          # Reduce quantum (buffer size) for lower latency
          # 256/48000 = ~5.3ms latency (default is often higher)
          "default.clock.quantum" = mkDefault 256;
          "default.clock.min-quantum" = mkDefault 256;
          "default.clock.max-quantum" = mkDefault 256;
        };
      };
    };

    # Additional system tweaks
    boot.kernel.sysctl = {
      # Increase max map count for games
      "vm.max_map_count" = mkDefault 2147483642;
      # Reduce swappiness for better gaming performance
      "vm.swappiness" = mkDefault 10;
    };

    # Enable udev rules for game controllers
    services.udev.packages = [ pkgs.game-devices-udev-rules ];
  };
}
