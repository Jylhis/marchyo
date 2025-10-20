{
  inputs,
  ...
}:

{
  imports = [
    # Include your hardware configuration
    ./hardware-configuration.nix
  ];

  # Marchyo user configuration
  marchyo.users.developer = {
    enable = true;
    fullname = "Developer Name";
    email = "developer@example.com";
  };

  # System hostname
  networking.hostName = "workstation";

  # Enable desktop environment (includes Hyprland, office apps, media apps)
  marchyo.desktop.enable = true;

  # Enable development tools (docker, virtualization, dev tools)
  marchyo.development.enable = true;

  # Bootloader configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  home-manager.users.developer = {
    imports = [
      inputs.marchyo.homeModules.default
    ];
    home.stateVersion = "25.11";
  };
  # User account
  users.users.developer = {
    #   isNormalUser = true;
    initialPassword = "";
    #   description = "Developer Name";
    #   extraGroups = [
    #     "networkmanager"
    #     "wheel"
    #   ];
  };

  nixpkgs.config.allowUnfree = true;

  # NixOS version
  system.stateVersion = "25.11";
}
