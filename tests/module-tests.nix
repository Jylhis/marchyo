# Module evaluation tests
# Tests that modules can be imported and evaluated without errors
{
  pkgs,
  lib,
  nixosModules,
  nix-colors,
  ...
}:
let
  # Test helper: evaluate NixOS config and return toplevel derivation
  # This validates that modules evaluate correctly without infinite recursion
  testNixOS =
    config:
    (lib.nixosSystem {
      inherit (pkgs) system;
      modules = [
        nixosModules
        {
          _module.args.colorSchemes = nix-colors.colorSchemes // (import ../colorschemes);
        }
        config
      ];
    }).config.system.build.toplevel;

  # Minimal NixOS configuration required for testing
  minimalConfig = {
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };
    system.stateVersion = "25.11";
    nixpkgs.config.allowUnfree = true;
  };

  # Helper to create test config with user
  withTestUser =
    extraConfig:
    lib.recursiveUpdate minimalConfig (
      lib.recursiveUpdate {
        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };
        users.users.testuser.uid = 1000;
      } extraConfig
    );
in
{
  # Test that NixOS modules can be imported without errors
  eval-nixos-modules = testNixOS minimalConfig;

  # Test that custom options are properly defined
  eval-custom-options = testNixOS (withTestUser { });

  # Test that desktop module can be enabled without errors
  eval-desktop-module = testNixOS (withTestUser {
    marchyo.desktop.enable = true;
  });

  # Test that development module can be enabled without errors
  eval-development-module = testNixOS (
    lib.recursiveUpdate minimalConfig {
      marchyo.development.enable = true;
    }
  );

  # Test that all feature flags can be enabled together without conflicts
  eval-all-features = testNixOS (withTestUser {
    marchyo = {
      desktop.enable = true;
      development.enable = true;
      media.enable = true;
      office.enable = true;
    };
  });

  # Test that theme system works with default settings
  eval-theme-default = testNixOS (withTestUser {
    marchyo.theme.enable = true;
  });

  # Test that theme system works with light variant
  eval-theme-light-variant = testNixOS (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "light";
    };
  });

  # Test that theme system works with nix-colors scheme
  eval-theme-nixcolors-scheme = testNixOS (withTestUser {
    marchyo.theme = {
      enable = true;
      scheme = "dracula";
    };
  });

  # Test that theme system works with custom colorscheme
  eval-theme-custom-scheme = testNixOS (withTestUser {
    marchyo.theme = {
      enable = true;
      scheme = "modus-vivendi-tinted";
    };
  });

  # Test that theme system works with inline color scheme definition
  eval-theme-inline-scheme = testNixOS (withTestUser {
    marchyo.theme = {
      enable = true;
      scheme = {
        slug = "test-scheme";
        name = "Test Scheme";
        author = "Test";
        variant = "dark";
        palette = {
          base00 = "000000";
          base01 = "111111";
          base02 = "222222";
          base03 = "333333";
          base04 = "444444";
          base05 = "555555";
          base06 = "666666";
          base07 = "777777";
          base08 = "888888";
          base09 = "999999";
          base0A = "aaaaaa";
          base0B = "bbbbbb";
          base0C = "cccccc";
          base0D = "dddddd";
          base0E = "eeeeee";
          base0F = "ffffff";
        };
      };
    };
  });
}
