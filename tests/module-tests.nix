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
  # Forces assertion evaluation (not just stateVersion) to catch real failures
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
        failedAssertions = builtins.filter (x: !x.assertion) eval.config.assertions;
        failedMessages = map (x: x.message) failedAssertions;
      in
      if failedAssertions != [ ] then
        throw "FAIL: ${name}: unexpected assertion failure(s): ${builtins.concatStringsSep "; " failedMessages}"
      else
        builtins.seq eval.config.system.stateVersion "pass"
    );

  # Test helper: verify NixOS config triggers a specific assertion failure

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
      composeKey = "caps";
    };
  });

  # Test 6b: Keyboard with compose key disabled
  eval-keyboard-no-compose = testNixOS "keyboard-no-compose" (withTestUser {
    marchyo.keyboard.composeKey = null;
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

  # Test 13: Worktrunk auto-enabled with development feature flag
  eval-worktrunk = testNixOS "worktrunk" (withTestUser {
    marchyo.development.enable = true;
  });

  # Test 15: Default browser (google-chrome) with desktop
  eval-defaults-browser = testNixOS "defaults-browser" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = "google-chrome";
  });

  # Test 16: Default editor (emacs) with desktop
  eval-defaults-editor = testNixOS "defaults-editor" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.editor = "emacs";
  });

  # Test 17: Null defaults (no apps managed by marchyo.defaults)
  eval-defaults-null = testNixOS "defaults-null" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = null;
    marchyo.defaults.editor = null;
    marchyo.defaults.terminalEditor = null;
    marchyo.defaults.videoPlayer = null;
    marchyo.defaults.audioPlayer = null;
    marchyo.defaults.musicPlayer = null;
    marchyo.defaults.fileManager = null;
    marchyo.defaults.terminalFileManager = null;
    marchyo.defaults.imageEditor = null;
    marchyo.defaults.email = null;
  });

  # Test 18: All defaults set to non-default values
  eval-defaults-all = testNixOS "defaults-all" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults = {
      browser = "firefox";
      editor = "vscode";
      terminalEditor = "neovim";
      videoPlayer = "vlc";
      audioPlayer = "vlc";
      musicPlayer = "spotify";
      fileManager = "thunar";
      terminalFileManager = "ranger";
      imageEditor = "gimp";
      email = "thunderbird";
    };
  });

  # Tracking: top-level enable with all sub-collectors off
  eval-tracking-minimal = testNixOS "tracking-minimal" (withTestUser {
    marchyo.tracking.enable = true;
  });

  # Tracking: shell history collector only
  eval-tracking-shell = testNixOS "tracking-shell" (withTestUser {
    marchyo.tracking = {
      enable = true;
      shell.enable = true;
    };
  });

  # Tracking: git scan collector
  eval-tracking-git = testNixOS "tracking-git" (withTestUser {
    marchyo.tracking = {
      enable = true;
      git.enable = true;
    };
  });

  # Tracking: editor with wakatime API key configured
  eval-tracking-editor-wakatime = testNixOS "tracking-editor-wakatime" (withTestUser {
    marchyo.tracking = {
      enable = true;
      editor.enable = true;
    };
    marchyo.users.testuser.wakatimeApiKey = "waka_test_00000000-0000-0000-0000-000000000000";
  });

  # Tracking: analysis module (exercises inline PrefixSpan + Ollama wiring)
  eval-tracking-analysis = testNixOS "tracking-analysis" (withTestUser {
    marchyo.tracking = {
      enable = true;
      analysis.enable = true;
    };
  });

  # Tracking: Langfuse LLM observability (native NixOS service + PostgreSQL)
  eval-tracking-langfuse = testNixOS "tracking-langfuse" (withTestUser {
    marchyo.tracking = {
      enable = true;
      langfuse.enable = true;
    };
  });

  # Tracking: Langfuse with custom port
  eval-tracking-langfuse-custom = testNixOS "tracking-langfuse-custom" (withTestUser {
    marchyo.tracking = {
      enable = true;
      langfuse = {
        enable = true;
        port = 4000;
      };
    };
  });

  # Test 19: Jotain as externally-managed editor (no package installed by marchyo)
  eval-defaults-jotain = testNixOS "defaults-jotain" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults = {
      editor = "jotain";
      terminalEditor = "jotain";
    };
  });

  # Test 14: Check Home Manager Hyprland configuration validity
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
