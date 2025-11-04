{
  pkgs,
  lib,
  nixosModules,
  homeModules,
  home-manager,
  ...
}:
let
  # Create test configurations by actually evaluating the modules
  # This is faster and more reliable than using nix-instantiate
  testNixOS = config:
    (lib.nixosSystem {
      system = pkgs.system;
      modules = [
        nixosModules
        config
      ];
    }).config.system.build.toplevel;

  testHome = config:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        homeModules
        config
      ];
    }).activationPackage;

  # Minimal NixOS config for testing
  minimalNixOS = {
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };
    system.stateVersion = "25.11";
    nixpkgs.config.allowUnfree = true;
  };
in
{
  # Test that NixOS modules can be imported without errors
  eval-nixos-modules = testNixOS minimalNixOS;

  # Test that Home Manager modules can be imported without errors
  eval-home-modules = testHome {
    home.stateVersion = "25.11";
    home.username = "testuser";
    home.homeDirectory = "/home/testuser";
  };

  # Test that custom options are properly defined
  eval-custom-options = testNixOS (
    minimalNixOS
    // {
      marchyo.users.testuser = {
        enable = true;
        fullname = "Test User";
        email = "test@example.com";
      };
    }
  );

  # Test that desktop module can be enabled without errors
  eval-desktop-module = testNixOS (
    minimalNixOS
    // {
      marchyo.desktop.enable = true;
      marchyo.users.testuser = {
        enable = true;
        fullname = "Test User";
        email = "test@example.com";
      };
      users.users.testuser.uid = 1000;
    }
  );

  # Test that development module can be enabled without errors
  eval-development-module = testNixOS (
    minimalNixOS
    // {
      marchyo.development.enable = true;
    }
  );

  # Test that all feature flags can be enabled together without conflicts
  eval-all-features = testNixOS (
    minimalNixOS
    // {
      marchyo = {
        desktop.enable = true;
        development.enable = true;
        media.enable = true;
        office.enable = true;
        users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
      };
      users.users.testuser.uid = 1000;
    }
  );
}
