# Main NixOS Configuration with Marchyo
#
# Edit this file to customize your system.
# After making changes, rebuild with:
#   sudo nixos-rebuild switch --flake .#hostname

{ config, pkgs, lib, inputs, ... }:

{
  # System Settings
  networking.hostName = "hostname";  # Change this to your hostname
  time.timeZone = "Europe/Zurich";   # Change to your timezone

  # Marchyo Configuration
  marchyo = {
    # Feature Flags - Enable the modules you need
    desktop.enable = true;      # Hyprland desktop environment
    development.enable = true;  # Docker, Git, development tools
    media.enable = false;       # Spotify, MPV, media applications
    office.enable = true;       # LibreOffice, document viewers

    # System Settings
    timezone = "Europe/Zurich";        # Sync with time.timeZone above
    defaultLocale = "en_US.UTF-8";

    # User Configuration
    users.yourname = {             # Change 'yourname' to your username
      enable = true;
      fullname = "Your Full Name"; # Change to your actual name
      email = "you@example.com";   # Change to your email
    };
  };

  # User Account
  users.users.yourname = {         # Match the username from marchyo.users
    isNormalUser = true;
    description = "Your Full Name";

    # Groups
    extraGroups = [
      "wheel"          # Enable sudo
      "networkmanager" # Network management
      "video"          # Video devices
      "audio"          # Audio devices
    ];

    # Optional: Set an initial password (change after first login!)
    # initialPassword = "changeme";

    # Optional: SSH keys
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAAC3... user@host"
    # ];
  };

  # Home Manager Configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.yourname = {  # Match your username
      imports = [
        inputs.marchyo.homeModules.default
        # Add additional home modules here
      ];

      home = {
        username = "yourname";  # Match your username
        homeDirectory = "/home/yourname";
        stateVersion = "24.11";

        # Additional user packages
        packages = with pkgs; [
          # Add any extra packages you want
          # Examples:
          # firefox
          # thunderbird
          # vscode
        ];
      };

      # Program-specific configuration
      programs = {
        # Git is configured by Marchyo, but you can override
        # git.extraConfig = {
        #   user.signingkey = "your-gpg-key";
        #   commit.gpgsign = true;
        # };
      };
    };
  };

  # Additional System Packages
  environment.systemPackages = with pkgs; [
    # Add system-wide packages here
    vim
    wget
    curl
    htop
  ];

  # Optional: SSH Server
  # services.openssh = {
  #   enable = true;
  #   settings = {
  #     PermitRootLogin = "no";
  #     PasswordAuthentication = false;
  #   };
  # };

  # Firewall
  networking.firewall = {
    enable = true;
    # allowedTCPPorts = [ 22 ];  # SSH
    # allowedUDPPorts = [ ];
  };

  # Bootloader
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Don't change this after installation!
  system.stateVersion = "24.11";
}
