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
  marchyo.users.admin = {
    enable = true;
    fullname = "System Administrator";
    email = "admin@example.com";
  };

  # System hostname
  networking.hostName = "my-server";

  # Bootloader configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Networking
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
  };

  # Timezone
  time.timeZone = "UTC";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # User account
  users.users.admin = {
    isNormalUser = true;
    description = "System Administrator";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Essential server packages
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    tmux
    rsync
  ];

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # NixOS version
  system.stateVersion = "24.11";
}
