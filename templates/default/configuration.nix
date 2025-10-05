{
  pkgs,
  ...
}:

{
  imports = [
    # Include your hardware configuration
    ./hardware-configuration.nix
  ];

  # Marchyo user configuration
  marchyo.users.myuser = {
    enable = true;
    fullname = "My Full Name";
    email = "me@example.com";
  };

  # System hostname
  networking.hostName = "my-system";

  # Enable Hyprland desktop environment (optional)
  marchyo.desktop.hyprland.enable = true;

  # Bootloader configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Networking
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # User account
  users.users.myuser = {
    isNormalUser = true;
    description = "My Full Name";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
  ];

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # NixOS version
  system.stateVersion = "24.11";
}
