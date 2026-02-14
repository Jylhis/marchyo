# Module evaluation tests
# Lightweight tests that verify modules can be evaluated without errors
# Uses pure evaluation instead of building toplevel derivations
{
  pkgs,
  lib,
  nixosModules,
  homeModules,
  ...
}:
let
  # Test helper: verify NixOS config evaluates without errors
  # Uses writeText + builtins.seq to force evaluation without building toplevel
  testNixOS =
    name: config:
    pkgs.writeText "eval-${name}" (
      let
        eval = lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            config
          ];
        };
      in
      # Force evaluation of config without building the expensive toplevel derivation
      builtins.seq eval.config.system.stateVersion "pass"
    );

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
  # Test 1: Minimal NixOS modules import
  eval-minimal = testNixOS "minimal" minimalConfig;

  # Test 2: Desktop feature flag with user
  eval-desktop = testNixOS "desktop" (withTestUser {
    marchyo.desktop.enable = true;
  });

  # Test 3: Development feature flag
  eval-development = testNixOS "development" (
    lib.recursiveUpdate minimalConfig {
      marchyo.development.enable = true;
    }
  );

  # Test 4: All features together
  eval-all-features = testNixOS "all-features" (withTestUser {
    marchyo = {
      desktop.enable = true;
      development.enable = true;
      media.enable = true;
      office.enable = true;
    };
  });

  # Test 5: Consolidated theme test - verifies all theme configurations work
  eval-themes = testNixOS "themes" (withTestUser {
    marchyo.theme = {
      enable = true;
      # Test dark variant (default)
      variant = "dark";
      # Test custom scheme
      scheme = "modus-vivendi-tinted";
    };
  });

  # Test 6: Consolidated keyboard test - verifies all keyboard configurations work
  eval-keyboard = testNixOS "keyboard" (withTestUser {
    marchyo.keyboard = {
      # Test hybrid layouts: strings, variants, and IME
      layouts = [
        "us"
        {
          layout = "fi";
          variant = "";
        }
        {
          layout = "cn";
          ime = "pinyin";
          label = "中文";
        }
        {
          layout = "jp";
          ime = "mozc";
        }
      ];
      autoActivateIME = true;
      imeTriggerKey = [
        "Super+I"
        "Alt+grave"
      ];
    };
  });

  # Test 7: Intel GPU configuration
  eval-graphics-intel = testNixOS "graphics-intel" (
    lib.recursiveUpdate minimalConfig {
      marchyo.graphics.vendors = [ "intel" ];
    }
  );

  # Test 8: AMD GPU configuration
  eval-graphics-amd = testNixOS "graphics-amd" (
    lib.recursiveUpdate minimalConfig {
      marchyo.graphics.vendors = [ "amd" ];
    }
  );

  # Test 9: NVIDIA GPU configuration
  eval-graphics-nvidia = testNixOS "graphics-nvidia" (
    lib.recursiveUpdate minimalConfig {
      marchyo.graphics.vendors = [ "nvidia" ];
    }
  );

  # Test 10: Hybrid Intel+NVIDIA PRIME offload
  eval-graphics-prime-offload = testNixOS "graphics-prime-offload" (
    lib.recursiveUpdate minimalConfig {
      marchyo.graphics = {
        vendors = [
          "intel"
          "nvidia"
        ];
        prime = {
          enable = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
          mode = "offload";
        };
      };
    }
  );

  # Test 11: Hybrid AMD+NVIDIA PRIME sync
  eval-graphics-prime-sync = testNixOS "graphics-prime-sync" (
    lib.recursiveUpdate minimalConfig {
      marchyo.graphics = {
        vendors = [
          "amd"
          "nvidia"
        ];
        prime = {
          enable = true;
          amdgpuBusId = "PCI:6:0:0";
          nvidiaBusId = "PCI:1:0:0";
          mode = "sync";
        };
      };
    }
  );

  # Test 12: Legacy mode (empty vendors on x86 defaults to Intel)
  eval-graphics-legacy = testNixOS "graphics-legacy" (
    lib.recursiveUpdate minimalConfig {
      marchyo.graphics.vendors = [ ];
    }
  );

  # Test 13: Check Home Manager Hyprland configuration validity
  check-home-hyprland-config =
    let
      # Define a minimal NixOS system with a user and hyprland enabled
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser = {
              imports = [ homeModules ];
            };
          })
        ];
      };
      # Extract the generated config file and package from the system
      hyprlandConfig = eval.config.home-manager.users.testuser.xdg.configFile."hypr/hyprland.conf".source;
      hyprland = eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.package;
    in
    pkgs.runCommand "check-hyprland-config"
      {
        nativeBuildInputs = [ hyprland ];
      }
      ''
        export XDG_RUNTIME_DIR="$(mktemp -d)"
        ${hyprland}/bin/hyprland --verify-config --config ${hyprlandConfig}

        echo "DONE"
        touch $out
      '';
}
