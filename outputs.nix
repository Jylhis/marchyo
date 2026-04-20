{ inputs }:
let
  inherit (inputs)
    nixpkgs
    home-manager
    vicinae
    noctalia
    stylix
    treefmt-nix
    ;

  overlay = import ./overlay.nix { inherit inputs; };

  # Shared config used by both nixosConfigurations.default and mkApps VM.
  sharedDemoConfig =
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

  nixosConfigurations.default = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      nixosModules.default
      sharedDemoConfig
      { networking.hostName = "marchyo-default"; }
    ];
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
          sharedDemoConfig
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
          sharedDemoConfig
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
