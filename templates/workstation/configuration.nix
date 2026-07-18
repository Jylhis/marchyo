{
  marchyo,
  ...
}:

{
  imports = [
    # Include your hardware configuration
    ./hardware-configuration.nix

    # Per-machine hardware fixes via nixos-hardware, re-exported by marchyo as
    # marchyo.nixosModules.hardware.<profile>. Pick the profile matching your
    # machine (full list: https://github.com/NixOS/nixos-hardware), e.g.:
    # marchyo.nixosModules.hardware.lenovo-thinkpad-x1-9th-gen
    # marchyo.nixosModules.hardware.framework-13-7040-amd
    # marchyo.nixosModules.hardware.dell-xps-13-9310
    # marchyo.nixosModules.hardware.common-pc-ssd
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

  # BYOK AI tooling (OpenRouter). Supply the API key via a sops-nix secret so it
  # never enters the Nix store. Add `config` to the module args above to use
  # `config.sops.secrets`. See docs/configuration/ai.mdx for the full workflow.
  # sops.defaultSopsFile = ./secrets/ai.yaml;
  # sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  # The default secret is root-owned 0400 under /run/secrets — set owner so the
  # desktop user's AI clients (aichat/pi) can read it.
  # sops.secrets."openrouter-api-key".owner = "developer";
  # marchyo.ai = {
  #   enable = true;
  #   openrouter = {
  #     apiKeyFile = config.sops.secrets."openrouter-api-key".path;
  #     defaultModel = "anthropic/claude-sonnet-4";
  #   };
  # };

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
