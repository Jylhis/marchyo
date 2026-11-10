_:

{
  imports = [
    ./hardware-configuration.nix

    # Per-machine hardware fixes via nixos-hardware: uncomment the input in
    # flake.nix, add `inputs` to this module's arguments, then pick the
    # profile matching your machine (full list:
    # https://github.com/NixOS/nixos-hardware), e.g.:
    # inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  networking.hostName = "workstation";

  # Hyprland desktop with the Marchyo shell, office and media apps.
  marchyo.desktop.enable = true;

  # Git, rootless Podman, virtualization and developer tools.
  marchyo.development.enable = true;

  # Creates the user account (wheel, networkmanager) and its Home Manager
  # configuration.
  marchyo.users.developer = {
    fullname = "Developer Name";
    email = "developer@example.com";
  };

  # Change it after the first login with `passwd`.
  users.users.developer.initialPassword = "changeme";

  # Defaults: { layout = "us"; variant = "altgr-intl"; } and "fi".
  # marchyo.keyboard.layouts = [
  #   "us"
  #   { layout = "cn"; ime = "pinyin"; }
  # ];

  # Defaults: "Europe/Zurich" and "en_US.UTF-8".
  # marchyo.timezone = "America/New_York";
  # marchyo.defaultLocale = "en_US.UTF-8";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # The NixOS release you first installed; do not change it on upgrades.
  system.stateVersion = "26.05";
}
