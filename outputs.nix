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
        # The marchyo-cli package uses a fixed-output derivation with a
        # placeholder hash (lib.fakeHash); the reference VM builds in CI must
        # not pull it in. Set this to true once the real FOD hash is
        # materialized in packages/marchyo-cli/package.nix.
        cli.enable = false;
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
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      palette = import ./modules/generic/jylhis-palette.nix {
        inherit pkgs lib;
        inherit (config.marchyo.theme) variant;
      };
    in
    {
      nixpkgs.config.allowUnfree = true;
      system.stateVersion = 6;

      stylix = {
        autoEnable = true;
        base16Scheme =
          if config.marchyo.theme.scheme != null then
            "${pkgs.base16-schemes}/share/themes/${config.marchyo.theme.scheme}.yaml"
          else
            palette.base16;
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
        inherit
          inputs
          noctalia
          vicinae
          stylix
          ;
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
          inputs
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
      # marchyo-cli is exposed via the overlay (consumed by modules/nixos/cli.nix)
      # but not surfaced as a flake-level package output yet. The package.nix
      # uses a fixed-output derivation with lib.fakeHash; once the FOD hash is
      # materialized on first successful local build, add `marchyo-cli` here.
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
