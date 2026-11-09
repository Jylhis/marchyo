{
  marchyo,
  ...
}:

{
  imports = [
    # Include your hardware configuration
    ./hardware-configuration.nix

    # Per-machine hardware fixes via nixos-hardware: uncomment the input in
    # flake.nix, add `inputs` to this module's arguments, then pick the
    # profile matching your machine (full list:
    # https://github.com/NixOS/nixos-hardware), e.g.:
    # inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
    # inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    # inputs.nixos-hardware.nixosModules.dell-xps-13-9310
    # inputs.nixos-hardware.nixosModules.common-pc-ssd
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

  # Enable development tools (rootless Podman, virtualization, dev tools)
  marchyo.development.enable = true;

  # Keyboard layouts and input methods (defaults shown, can be customized)
  # marchyo.keyboard.layouts = [
  #   "us"                               # US English keyboard
  #   "fi"                               # Finnish keyboard
  #   { layout = "cn"; ime = "pinyin"; } # Chinese with Pinyin IME
  # ];

  # Bootloader configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  home-manager.users.developer = {
    imports = [
      marchyo.homeManagerModules.default
    ];
    home.stateVersion = "25.11";
  };
  # User account -- change password after first login
  users.users.developer = {
    isNormalUser = true;
    initialPassword = "changeme";
    description = "Developer Name";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # NixOS version
  system.stateVersion = "25.11";
}
