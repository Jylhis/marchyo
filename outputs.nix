{ inputs }:
let
  inherit (inputs)
    nixpkgs
    nixpkgs-stable
    home-manager
    home-manager-stable
    home-manager-droid
    nix-darwin
    nix-darwin-stable
    nix-on-droid
    vicinae
    noctalia
    stylix
    stylix-stable
    sops-nix
    llm-agents
    treefmt-nix
    ;

  overlay = import ./overlay.nix { inherit inputs; };

  # marchyo's overlay plus llm-agents.nix (exposes pkgs.llm-agents.<agent>,
  # e.g. claude-code, from its Numtide-cached pinned set).
  overlayList = [
    overlay
    llm-agents.overlays.default
  ];

  # Single source of truth for the per-system input set. x86_64-darwin is the
  # last nixpkgs release supporting Intel macOS (26.11 drops it), so it rides
  # the stable nixos-26.05 set together with the matching release-branch
  # home-manager / nix-darwin / stylix; every other system rides unstable.
  # This is the ONLY place the x86_64-darwin special-case is decided — both the
  # consumer-facing builders below and `legacyPackages` flow through it.
  inputsFor =
    system:
    if system == "x86_64-darwin" then
      {
        nixpkgs = nixpkgs-stable;
        home-manager = home-manager-stable;
        nix-darwin = nix-darwin-stable;
        stylix = stylix-stable;
      }
    else
      {
        inherit
          nixpkgs
          home-manager
          nix-darwin
          stylix
          ;
      };

  # Instantiate the correct nixpkgs for a system, with marchyo's overlay applied
  # and unfree allowed. Drives `legacyPackages`, the x86_64-darwin pkgs override
  # in `mkDarwinSystem`, and standalone Home Manager configs.
  mkPkgs =
    system:
    import (inputsFor system).nixpkgs {
      inherit system;
      overlays = overlayList;
      config.allowUnfree = true;
    };

  # Shared config used by both nixosConfigurations and mkApps VM.
  sharedNixosConfig =
    { lib, ... }:
    {
      nixpkgs.overlays = overlayList;
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
  # Stylix base16 scheme + fonts come from modules/generic/stylix.nix (imported
  # via darwinModules.default), shared with the NixOS configurations.
  sharedDarwinConfig =
    { pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      system.stateVersion = 6;

      environment.systemPackages = [
        pkgs.ghostty-bin.terminfo
      ];

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
        wallpaper.enable = true;
      };
    };
  };

  # Shared config for nixOnDroidConfigurations (nix-on-droid's own module
  # vocabulary — NOT NixOS options).
  sharedNixOnDroidConfig =
    { pkgs, ... }:
    {
      time.timeZone = "UTC";
      system.stateVersion = "24.05";
      user.shell = "${pkgs.zsh}/bin/zsh";
    };

  # Helper to build standalone Home Manager configurations.
  mkHomeConfiguration =
    {
      system,
      homeDirectory,
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs system;
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
        sops-nix.homeManagerModules.sops
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
        sops-nix.homeManagerModules.sops
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
        sops-nix.nixosModules.sops
        { nixpkgs.overlays = overlayList; }

        ./modules/nixos/default.nix
      ];
    };
    inherit (home-manager.nixosModules) home-manager;
  };

  # Darwin module set, parameterized by which home-manager darwin module to
  # bake in so each darwinConfiguration pairs its nixpkgs with the matching HM
  # (release branches assume their matching nixpkgs):
  #   aarch64 → unstable nixpkgs  + home-manager (master)
  #   x86_64  → nixos-26.05 stable + home-manager-stable (release-26.05)
  mkDarwinModules = hmDarwinModule: {
    imports = [
      hmDarwinModule
      hmSharedConfig
      { nixpkgs.overlays = overlayList; }

      ./modules/darwin/default.nix
    ];
  };

  darwinModules = {
    default = mkDarwinModules home-manager.darwinModules.home-manager;
  };

  homeManagerModules = {
    default = ./modules/home/default.nix;
    _1password = ./modules/home/_1password.nix;
  };

  # nix-on-droid module. Droid-native and minimal — no marchyo overlay, no NixOS
  # modules, and NOT the marchyo HM modules (nix-on-droid ships HM 24.05).
  nixOnDroidModules = {
    default = ./modules/nix-on-droid/default.nix;
  };

  # Batteries-included system builders. A downstream consumer that adds only
  # `marchyo` as an input can build any system with these — the correct nixpkgs
  # (unstable, or stable 26.05 for x86_64-darwin), home-manager, nix-darwin,
  # stylix, overlay and marchyo modules are all selected automatically via
  # `inputsFor`. The consumer supplies only their own config modules.

  # All NixOS targets are Linux, so they always ride unstable. `nixosModules.default`
  # already bakes in home-manager + stylix + sops + the overlay (overlayList).
  # `overlays`/`config` let a consumer add their own on top; allowUnfree defaults
  # on (set plainly — nixpkgs.config is a freeform attrset, so a priority wrapper
  # like mkDefault would leak through to nixpkgs unresolved).
  mkNixosSystem =
    {
      system,
      modules ? [ ],
      specialArgs ? { },
      overlays ? [ ],
      config ? { },
    }:
    (inputsFor system).nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        nixosModules.default
        {
          nixpkgs.overlays = overlays;
          nixpkgs.config = {
            allowUnfree = true;
          }
          // config;
        }
      ]
      ++ modules;
    };

  # Darwin builder. Selects the nix-darwin builder, home-manager darwin module
  # and stylix module matching the system's nixpkgs (release branches assume
  # their matching nixpkgs). `overlays`/`config` are the consumer's additions on
  # top of marchyo's overlayList / allowUnfree.
  #
  # For x86_64-darwin nix-darwin is handed an externally-built stable pkgs and
  # the config/overlays the shared modules set are mkForce-cleared (nix-darwin
  # rejects nixpkgs.pkgs alongside nixpkgs.overlays). The consumer's overlays and
  # config therefore must be baked INTO that instantiation here — setting them
  # via a module would be silently cleared.
  mkDarwinSystem =
    {
      system,
      modules ? [ ],
      specialArgs ? { },
      overlays ? [ ],
      config ? { },
    }:
    let
      sel = inputsFor system;
      cfg = {
        allowUnfree = true;
      }
      // config;
    in
    sel.nix-darwin.lib.darwinSystem {
      inherit system specialArgs;
      modules = [
        (mkDarwinModules sel.home-manager.darwinModules.home-manager)
        sel.stylix.darwinModules.stylix
      ]
      ++ (
        if system == "x86_64-darwin" then
          [
            (
              { lib, ... }:
              {
                nixpkgs.pkgs = import sel.nixpkgs {
                  inherit system;
                  overlays = overlayList ++ overlays;
                  config = cfg;
                };
                nixpkgs.config = lib.mkForce { };
                nixpkgs.overlays = lib.mkForce [ ];
              }
            )
          ]
        else
          [
            {
              nixpkgs.overlays = overlays;
              nixpkgs.config = cfg;
            }
          ]
      )
      ++ modules;
    };
in
{
  inherit
    nixosModules
    darwinModules
    homeManagerModules
    nixOnDroidModules
    ;

  # Batteries-included builders for downstream consumers. System-parameterized,
  # so this is a plain top-level output (not wrapped in forAllSystems).
  lib = {
    inherit
      mkNixosSystem
      mkDarwinSystem
      mkHomeConfiguration
      inputsFor
      mkPkgs
      ;
  };

  overlays.default = overlay;

  templates = rec {
    default = workstation;
    workstation = {
      path = ./templates/workstation;
      description = "Full developer workstation with desktop and development tools";
    };
  };

  # Reference configs built through the same exported builders consumers use,
  # so they exercise the system-aware input selection end to end.
  nixosConfigurations = {
    x86_64 = mkNixosSystem {
      system = "x86_64-linux";
      modules = [
        sharedNixosConfig
        { networking.hostName = "marchyo-x86-64"; }
      ];
    };
    aarch64 = mkNixosSystem {
      system = "aarch64-linux";
      modules = [
        sharedNixosConfig
        {
          networking.hostName = "marchyo-aarch64";
          # Intel GPU drivers are x86-only; clear for aarch64
          marchyo.graphics.vendors = nixpkgs.lib.mkForce [ ];
        }
      ];
    };
  };

  # aarch64 rides unstable; x86_64 is transparently pinned to stable nixos-26.05
  # (with matching nix-darwin-26.05 + stable HM/stylix) by `mkDarwinSystem`.
  darwinConfigurations = {
    aarch64 = mkDarwinSystem {
      system = "aarch64-darwin";
      modules = [
        sharedDarwinConfig
        { networking.hostName = "marchyo-aarch64"; }
      ];
    };
    x86_64 = mkDarwinSystem {
      system = "x86_64-darwin";
      modules = [
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

  # nix-on-droid (Android terminal). Build with:
  #   nix build .#nixOnDroidConfigurations.aarch64.activationPackage
  # Kept internally consistent on nix-on-droid's own (2024) nixpkgs + HM 24.05;
  # the marchyo overlay is intentionally NOT applied (built against unstable).
  nixOnDroidConfigurations = {
    aarch64 = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nix-on-droid.inputs.nixpkgs {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };
      modules = [
        nixOnDroidModules.default
        sharedNixOnDroidConfig
      ];
      home-manager-path = home-manager-droid.outPath;
    };
  };

  # System-aware: x86_64-darwin → stable nixos-26.05, every other system →
  # unstable. Always with marchyo's overlay applied and unfree allowed.
  legacyPackages = mkPkgs;

  mkPackages =
    { system }:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = overlayList;
      };
    in
    {
      inherit (pkgs) marchyo-wallpapers;
    }
    // nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
      inherit (pkgs)
        hyprmon
        plymouth-marchyo-theme
        openviking
        pi
        ;
    }
    // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
      inherit (pkgs) wallpapper;
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
      inherit
        nixpkgs
        home-manager
        nix-on-droid
        home-manager-droid
        ;
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
