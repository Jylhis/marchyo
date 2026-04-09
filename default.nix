# default.nix — npins-based entry point for developers
# Provides the same modules, overlays, and checks as flake.nix
# but uses npins for pinning instead of flake.lock.
#
# Usage:
#   nix-build -A checks.x86_64-linux    # Run evaluation tests
#   nix-build -A formatter              # Build treefmt wrapper
#   nix-build -A nixosConfigurations.default.config.system.build.toplevel
{
  sources ? import ./npins,
  system ? builtins.currentSystem,
}:
let
  # Evaluate upstream flakes via flake-compat
  callFlake = src: (import sources.flake-compat { inherit src; }).defaultNix;

  hmFlake = callFlake sources.home-manager;
  stylixFlake = callFlake sources.stylix;
  vicinaFlake = callFlake sources.vicinae;
  noctaliaFlake = callFlake sources.noctalia;
  worktrunkFlake = callFlake sources.worktrunk;
  treefmtFlake = callFlake sources.treefmt-nix;

  inherit (sources) nixpkgs;

  # Extend lib with nixosSystem (normally only available in flake context)
  lib = (import nixpkgs { inherit system; }).lib.extend (
    final: _prev: {
      nixosSystem =
        args:
        import "${nixpkgs}/nixos/lib/eval-config.nix" (
          args // { lib = final; } // final.optionalAttrs (!args ? system) { system = null; }
        );
    }
  );

  # Construct inputs shape for overlays/default.nix
  inputs = {
    vicinae = vicinaFlake;
    noctalia = noctaliaFlake;
    worktrunk = worktrunkFlake;
  };
  overlay = import ./overlays { inherit inputs; };

  # NixOS modules (mirrors flake.nix nixosModules.default)
  nixosModules = {
    default = {
      imports = [
        hmFlake.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            sharedModules = [
              noctaliaFlake.homeModules.default
              vicinaFlake.homeManagerModules.default
            ];
            extraSpecialArgs = {
              noctalia = noctaliaFlake;
              vicinae = vicinaFlake;
              stylix = stylixFlake;
            };
          };
        }
        stylixFlake.nixosModules.stylix
        ./modules/nixos/default.nix
      ];
    };
  };

  homeModules = {
    default = ./modules/home/default.nix;
    _1password = ./modules/home/_1password.nix;
  };

  # Reference NixOS configuration (for CI build and VM)
  nixosConfigurations.default = lib.nixosSystem {
    inherit system;
    modules = [
      nixosModules.default
      (
        { lib, ... }:
        {
          networking.hostName = "marchyo-default";
          nixpkgs.overlays = [ overlay ];
          nixpkgs.config.allowUnfree = true;

          # Minimal bootable system
          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.loader.grub.enable = lib.mkForce false;
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
          system.stateVersion = "25.11";

          # All Marchyo features
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
        }
      )
    ];
  };

  # Checks (evaluation tests) — nested under system for flake-compatible paths
  checks.${system} = import ./tests {
    inherit system lib nixpkgs;
    home-manager = hmFlake;
    nixosModules = nixosModules.default;
    homeModules = homeModules.default;
  };

  # Formatter (treefmt) — nested under system for flake-compatible paths
  formatter.${system} =
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    treefmtFlake.lib.mkWrapper pkgs (import ./treefmt.nix);
in
{
  inherit
    nixosModules
    homeModules
    overlay
    checks
    formatter
    nixosConfigurations
    lib
    ;
}
