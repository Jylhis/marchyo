{ inputs }:
let
  inherit (inputs)
    nixpkgs
    home-manager
    nix-darwin
    vicinae
    noctalia
    stylix
    treefmt-nix
    ;

  overlay = import ./overlay.nix { inherit inputs; };

  # Shared config used by both nixosConfigurations and mkApps VM.
  sharedNixosConfig =
    { lib, ... }:
    {
      nixpkgs.overlays = [ overlay ];
      nixpkgs.config.allowUnfree = true;

      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.grub.enable = lib.mkForce false;
      fileSystems."/" = {
        device = "/dev/vda";
        fsType = "ext4";
      };
      system.stateVersion = "25.11";

      marchyo = {
        desktop.enable = true;
        development.enable = true;
        media.enable = true;
        office.enable = true;
        graphics.vendors = [ "intel" ];
        users.developer = {
          fullname = "Marchyo Developer";
          email = "dev@example.org";
        };
      };

      users.users.developer = {
        isNormalUser = true;
        password = "password";
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
      };
      services.getty.autologinUser = "developer";
    };

  # Shared config for darwinConfigurations.
  sharedDarwinConfig =
    { pkgs, config, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      system.stateVersion = 6;

      stylix = {
        autoEnable = true;
        base16Scheme =
          if config.marchyo.theme.scheme != null then
            "${pkgs.base16-schemes}/share/themes/${config.marchyo.theme.scheme}.yaml"
          else if config.marchyo.theme.variant == "dark" then
            {
              scheme = "Jylhis Roast";
              author = "Markus Jylhankangas (jylhis.com)";
              base00 = "1a1714";
              base01 = "242019";
              base02 = "2a2520";
              base03 = "8a7f72";
              base04 = "b0a496";
              base05 = "e8e0d4";
              base06 = "f0eae0";
              base07 = "363230";
              base08 = "ff5f59";
              base09 = "e89b5e";
              base0A = "d0bc00";
              base0B = "b3c785";
              base0C = "80c8b3";
              base0D = "2fafff";
              base0E = "c8a5ff";
              base0F = "d4884a";
            }
          else
            {
              scheme = "Jylhis Paper";
              author = "Markus Jylhankangas (jylhis.com)";
              base00 = "faf7f2";
              base01 = "f0ebe3";
              base02 = "e8e1d6";
              base03 = "8a7f72";
              base04 = "6b5f54";
              base05 = "2c2825";
              base06 = "1e1b18";
              base07 = "fefdfb";
              base08 = "a60000";
              base09 = "9a5a2a";
              base0A = "6f5500";
              base0B = "3d5a1f";
              base0C = "134a4a";
              base0D = "0031a9";
              base0E = "4a2d80";
              base0F = "b5703c";
            };
        fonts = {
          serif = {
            package = pkgs.literata;
            name = "Literata";
          };
          sansSerif = {
            package = pkgs.liberation_ttf;
            name = "Liberation Sans";
          };
          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font";
          };
        };
      };

      marchyo = {
        development.enable = true;
        users.developer = {
          fullname = "Marchyo Developer";
          email = "dev@example.org";
        };
      };

      users.users.developer = {
        home = "/Users/developer";
      };
    };

  # Mock osConfig for standalone Home Manager configurations.
  # Provides the minimum structure that HM modules access directly
  # (without `or` defaults).
  mockOsConfig = {
    marchyo = {
      keyboard = {
        layouts = [ "us" ];
        options = [ ];
        autoActivateIME = false;
        imeTriggerKey = [ ];
        composeKey = null;
      };
      defaultLocale = "en_US.UTF-8";
      users.developer = {
        enable = true;
        name = "developer";
        fullname = "Marchyo Developer";
        email = "dev@example.org";
        wakatimeApiKey = null;
      };
      desktop = {
        enable = false;
        useWofi = false;
      };
      development.enable = false;
      graphics = {
        vendors = [ ];
        prime = {
          enable = false;
          mode = "";
        };
      };
      defaults = { };
      tracking = { };
      theme = {
        enable = false;
        variant = "dark";
      };
    };
  };

  # Helper to build standalone Home Manager configurations.
  mkHomeConfiguration =
    {
      system,
      homeDirectory,
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
        config.allowUnfree = true;
      };
      extraSpecialArgs = {
        osConfig = mockOsConfig;
        inherit noctalia vicinae stylix;
      };
      modules = [
        homeManagerModules.default
        noctalia.homeModules.default
        vicinae.homeManagerModules.default
        {
          home.username = "developer";
          home.homeDirectory = homeDirectory;
          home.stateVersion = "25.11";
        }
      ];
    };

  # Shared home-manager settings for module outputs
  hmSharedConfig = {
    home-manager = {
      useGlobalPkgs = true;
      sharedModules = [
        noctalia.homeModules.default
        vicinae.homeManagerModules.default
      ];
      extraSpecialArgs = {
        inherit
          noctalia
          vicinae
          stylix
          ;
      };
    };
  };

  nixosModules = {
    default = {
      imports = [
        home-manager.nixosModules.home-manager
        hmSharedConfig
        stylix.nixosModules.stylix
        { nixpkgs.overlays = [ overlay ]; }

        ./modules/nixos/default.nix
      ];
    };
    inherit (home-manager.nixosModules) home-manager;
  };

  darwinModules = {
    default = {
      imports = [
        home-manager.darwinModules.home-manager
        hmSharedConfig
        { nixpkgs.overlays = [ overlay ]; }

        ./modules/darwin/default.nix
      ];
    };
  };

  homeManagerModules = {
    default = ./modules/home/default.nix;
    _1password = ./modules/home/_1password.nix;
  };
in
{
  inherit nixosModules darwinModules homeManagerModules;

  overlays.default = overlay;

  templates = rec {
    default = workstation;
    workstation = {
      path = ./templates/workstation;
      description = "Full developer workstation with desktop and development tools";
    };
  };

  nixosConfigurations = {
    x86_64 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixosModules.default
        sharedNixosConfig
        { networking.hostName = "marchyo-x86-64"; }
      ];
    };
    aarch64 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixosModules.default
        sharedNixosConfig
        {
          networking.hostName = "marchyo-aarch64";
          # Intel GPU drivers are x86-only; clear for aarch64
          marchyo.graphics.vendors = nixpkgs.lib.mkForce [ ];
        }
      ];
    };
  };

  darwinConfigurations = {
    aarch64 = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        darwinModules.default
        stylix.darwinModules.stylix
        sharedDarwinConfig
        { networking.hostName = "marchyo-aarch64"; }
      ];
    };
    x86_64 = nix-darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      modules = [
        darwinModules.default
        stylix.darwinModules.stylix
        sharedDarwinConfig
        { networking.hostName = "marchyo-x86-64"; }
      ];
    };
  };

  # Standalone Home Manager configurations (Linux only — many HM modules
  # depend on Wayland/Hyprland and are not darwin-compatible).
  # Darwin home-manager is tested through darwinConfigurations instead.
  homeConfigurations = {
    "x86_64-linux" = mkHomeConfiguration {
      system = "x86_64-linux";
      homeDirectory = "/home/developer";
    };
    "aarch64-linux" = mkHomeConfiguration {
      system = "aarch64-linux";
      homeDirectory = "/home/developer";
    };
  };

  legacyPackages =
    system:
    import nixpkgs {
      inherit system;
      overlays = [ overlay ];
      config.allowUnfree = true;
    };

  mkPackages =
    { system }:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
    in
    {
      inherit (pkgs) hyprmon plymouth-marchyo-theme;
    };

  mkDocs =
    { system }:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      # NixOS module eval is always x86_64-linux regardless of build host.
      nixosConfig = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixosModules.default
          sharedNixosConfig
          { networking.hostName = "marchyo-docs"; }
        ];
      };
      docs = import ./docs {
        inherit pkgs;
        inherit (nixpkgs) lib;
        inherit nixosConfig;
        sourceRoot = ./.;
      };
    in
    {
      docs = docs.site;
      docs-options = docs.optionsReference;
      docs-lib = docs.libReference;
    };

  mkChecks =
    { system }:
    import ./tests {
      inherit system;
      inherit (nixpkgs) lib;
      inherit nixpkgs home-manager;
      nixosModules = nixosModules.default;
      homeManagerModules = homeManagerModules.default;
    };

  mkFormatter =
    { system }:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    treefmt-nix.lib.mkWrapper pkgs (import ./treefmt.nix);

  mkApps =
    { system }:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixosModules.default
          sharedNixosConfig
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
              networking.hostName = "marchyo-vm";
              virtualisation = {
                memorySize = 4096;
                cores = 4;
                graphics = true;
              };
            }
          )
        ];
      };
      runner = pkgs.writeShellScriptBin "run-vm" ''
        exec ${vm.config.system.build.vm}/bin/run-${vm.config.networking.hostName}-vm "$@"
      '';
    in
    {
      default = {
        type = "app";
        program = "${runner}/bin/run-vm";
        meta.description = "Run a QEMU VM with all Marchyo features enabled";
      };
    };
}
