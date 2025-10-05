# Minimal Server Configuration Example
#
# This configuration provides a minimal NixOS server setup with Marchyo.
# Suitable for headless servers, VPS, containers.
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
  networking.hostName = "minimal-server";
  time.timeZone = "UTC";

  # Marchyo Configuration
  marchyo = {
    # No desktop environment for servers
    desktop.enable = false;
    development.enable = false;
    media.enable = false;
    office.enable = false;

    # System settings
    timezone = "UTC";
    defaultLocale = "en_US.UTF-8";

    # Define admin user
    users.admin = {
      enable = true;
      fullname = "System Administrator";
      email = "admin@example.com";
    };
  };

  # User Configuration
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable sudo
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
      # "ssh-ed25519 AAAAC3... user@host"
    ];
  };

  # SSH Configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH only
  };

  # Automatic Updates (optional, enable with caution)
  # system.autoUpgrade = {
  #   enable = false;
  #   allowReboot = false;
  #   flake = "github:yourusername/yourconfig";
  # };

  # Home Manager for admin user
  home-manager.users.admin = {
    imports = [
      # Marchyo home modules imported via flake
    ];

    home.stateVersion = "24.11";

    # Minimal shell setup
    programs.bash.enable = true;
    programs.git.enable = true;
  };

  system.stateVersion = "24.11";
}
