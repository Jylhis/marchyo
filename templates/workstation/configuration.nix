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
  marchyo.users.developer = {
    enable = true;
    fullname = "Developer Name";
    email = "developer@example.com";
  };

  # System hostname
  networking.hostName = "workstation";

  # Desktop environment - Hyprland with full features
  # marchyo.desktop.hyprland.enable = true;

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
  users.users.developer = {
    isNormalUser = true;
    initialPassword = "marchyo";
    description = "Developer Name";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "libvirtd"
    ];
  };

  # Development tools
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    neovim
    vscode

    # Version control
    git
    git-lfs
    gh

    # Terminal tools
    tmux
    zellij
    kitty
    alacritty

    # Shell enhancements
    starship
    zoxide
    fzf
    ripgrep
    fd

    # System monitoring
    htop
    btop
    fastfetch

    # Development
    docker-compose
    kubectl
    terraform
    ansible

    # Build tools
    gnumake
    cmake
    gcc

    # Network tools
    wget
    curl
    nmap

    # File management
    tree
    rsync
    rclone
  ];

  # Docker/container support
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Virtualization support
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Trusted users for Nix
  nix.settings.trusted-users = [
    "root"
    "developer"
  ];

  # Enable sound

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Git configuration
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # NixOS version
  system.stateVersion = "25.11";
}
