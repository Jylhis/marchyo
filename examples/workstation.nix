# Developer Workstation Configuration Example
#
# This configuration provides a full-featured developer workstation with:
# - Hyprland desktop environment
# - Complete development tools (Docker, Git, GitHub CLI)
# - Office applications
# - Modern shell with enhancements
#
# Usage:
#   1. Copy to your configuration directory
#   2. Adjust hostname, timezone, and user details
#   3. Add hardware-configuration.nix
#   4. Deploy with nixos-rebuild

{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    # Add Marchyo modules here when using as flake input
  ];

  # System Configuration
  networking.hostName = "dev-workstation";

  # Marchyo Configuration
  marchyo = {
    # Enable all productivity features
    desktop.enable = true; # Hyprland, Wayland, Fonts, Graphics
    development.enable = true; # Docker, GitHub CLI, Dev tools
    media.enable = false; # Optional: Enable for Spotify, MPV
    office.enable = true; # LibreOffice, Document viewers

    # Localization
    timezone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";

    # Developer user
    users.developer = {
      enable = true;
      fullname = "Developer Name";
      email = "developer@company.com";
    };
  };

  # User Configuration
  users.users.developer = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # Sudo access
      "networkmanager" # Network management
      "video" # Video devices
      "audio" # Audio devices
    ];
    # Optional: Set initial password
    # initialPassword = "changeme";
  };

  # Additional System Packages
  environment.systemPackages = with pkgs; [
    # Browsers (in addition to Brave from desktop)
    firefox

    # Communication
    slack
    discord

    # Code editors (in addition to included tools)
    # vscode
    # jetbrains.idea-community

    # System monitoring
    htop

    # Utilities
    tree
    unzip
    wget
    curl
  ];

  # Development Services
  virtualisation = {
    # Docker is enabled via marchyo.development.enable
    # Additional virtualization if needed:
    # libvirtd.enable = true;
  };

  # Better font rendering
  fonts.fontconfig.subpixel.rgba = "rgb";

  # Home Manager Configuration
  home-manager.users.developer = {
    imports = [
      # Marchyo home modules imported via flake
    ];

    home.stateVersion = "24.11";

    # Development directories
    home.file.".config/dev-notes.md".text = ''
      # Development Notes

      ## Useful Commands
      - `docker ps` - List running containers
      - `gh pr list` - List pull requests
      - `lazydocker` - Docker TUI
      - `lazygit` - Git TUI

      ## Project Locations
      - ~/projects/
      - ~/work/
    '';

    # Git configuration (extends Marchyo's git module)
    programs.git = {
      extraConfig = {
        # Add company-specific git config
        # url."ssh://git@github.com/company/" = {
        #   insteadOf = "https://github.com/company/";
        # };
      };
    };

    # Additional packages for user
    home.packages = with pkgs; [
      # Terminal utilities
      tmux
      neovim

      # Development specific
      postman
      insomnia
    ];
  };

  system.stateVersion = "24.11";
}
