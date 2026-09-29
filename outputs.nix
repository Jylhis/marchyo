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
    nixos-hardware
    vicinae
    ncro
    noctalia
    stylix
    stylix-stable
    sops-nix
    treefmt-nix
    ;

  overlay = import ./overlay.nix { inherit inputs; };

  overlayList = [ overlay ];

  # Single source of truth for the per-system input set, and the ONLY place the
  # x86_64-darwin special-case is decided (the builders below and legacyPackages
  # all flow through it). x86_64-darwin is the last nixpkgs release supporting
  # Intel macOS (26.11 drops it), so it rides stable nixos-26.05 with the
  # matching release-branch home-manager / nix-darwin / stylix; everything else
  # rides unstable.
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

  mkPkgs =
    system:
    import (inputsFor system).nixpkgs {
      inherit system;
      overlays = overlayList;
      config.allowUnfree = true;
    };

  # Droid input stack, pinned independently of the unstable/stable selector:
  # nix-on-droid's own nixpkgs with HM-24.05 home-manager-droid.
  droidInputs = {
    nixpkgs = nix-on-droid.inputs.nixpkgs;
    home-manager = home-manager-droid;
  };

  sharedNixosConfig =
    { lib, ... }:
    {
      nixpkgs.overlays = overlayList;
      nixpkgs.config.allowUnfree = true;

      # Plain `false`, no lib.mkForce: modules/nixos/boot.nix sets systemd-boot
      # with lib.mkDefault, so a consumer (this reference VM included) can turn
      # it off normally.
      boot.loader.systemd-boot.enable = false;
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

  # Mock osConfig for standalone HM configs: the minimum structure HM modules
  # access directly (without `or` defaults).
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
      theme = {
        enable = false;
        variant = "dark";
        wallpaper.enable = true;
      };
    };
  };

  # Shared config for nixOnDroidConfigurations (nix-on-droid's own module
  # vocabulary, NOT NixOS options).
  sharedNixOnDroidConfig =
    { pkgs, ... }:
    {
      time.timeZone = "UTC";
      system.stateVersion = "24.05";
      user.shell = "${pkgs.bashInteractive}/bin/bash";
    };

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
        # Declares programs.vicinae.input-server: the cap_dac_override wrapper
        # the launcher needs to inject keystrokes. Upstream defaults it ON, so
        # modules/nixos/launcher.nix gates it behind marchyo.launcher.* (so
        # importing this module alone does not install the capability).
        vicinae.nixosModules.default
        # ncro service options; enablement is gated by marchyo.nix.router.enable
        # in modules/nixos/ncro.nix. NixOS only (systemd DynamicUser service),
        # deliberately absent from mkDarwinModules and hmSharedConfig.
        ncro.nixosModules.default
        { nixpkgs.overlays = overlayList; }

        ./modules/nixos/default.nix
      ];
    };
    inherit (home-manager.nixosModules) home-manager;
    # Complete nixos-hardware profile set, re-exported wholesale (profiles are
    # lazy, so unused ones cost nothing). A host imports its profile directly:
    #   imports = [ marchyo.nixosModules.hardware.lenovo-thinkpad-x1-9th-gen ];
    hardware = nixos-hardware.nixosModules;
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

  # nix-on-droid module. Droid-native and minimal: no marchyo overlay, no NixOS
  # modules, and NOT the marchyo HM modules (nix-on-droid ships HM 24.05).
  nixOnDroidModules = {
    default = ./modules/nix-on-droid/default.nix;
  };

  # Batteries-included system builders: a consumer that adds only `marchyo` as
  # an input builds any system with these, with nixpkgs / home-manager /
  # nix-darwin / stylix / overlay / modules selected automatically via inputsFor.

  # allowUnfree is set plainly, not via a priority wrapper: nixpkgs.config is a
  # freeform attrset, so mkDefault/mkForce would leak through to nixpkgs
  # unresolved. `overlays`/`config` are the consumer's additions on top of
  # marchyo's baked-in overlayList.
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

  # Darwin builder: selects the nix-darwin / home-manager / stylix modules
  # matching the system's nixpkgs. `overlays`/`config` are the consumer's
  # additions on top of marchyo's overlayList / allowUnfree.
  #
  # For x86_64-darwin nix-darwin is handed an externally-built stable pkgs and
  # the shared modules' config/overlays are mkForce-cleared (nix-darwin rejects
  # nixpkgs.pkgs alongside nixpkgs.overlays). The consumer's overlays and config
  # therefore must be baked INTO that instantiation here; setting them via a
  # module would be silently cleared.
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

  # nix-on-droid builder, fixed to aarch64-linux (the only Android target).
  # The marchyo overlay is NOT forced on (it is Linux-desktop-shaped); overlays
  # default to [] and a consumer can opt in. The droid stack stays on HM 24.05,
  # so the marchyo HM modules (modules/home/*) and the marchyo.* options
  # namespace stay out of scope; the droid modules reuse only the
  # HM-version-agnostic generic modules.
  mkNixOnDroidConfiguration =
    {
      modules ? [ ],
      extraSpecialArgs ? { },
      overlays ? [ ],
      config ? { },
    }:
    nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import droidInputs.nixpkgs {
        system = "aarch64-linux";
        inherit overlays;
        config = {
          allowUnfree = true;
        }
        // config;
      };
      inherit extraSpecialArgs;
      modules = [
        nixOnDroidModules.default
        sharedNixOnDroidConfig
      ]
      ++ modules;
      home-manager-path = droidInputs.home-manager.outPath;
    };
in
{
  inherit
    nixosModules
    darwinModules
    homeManagerModules
    nixOnDroidModules
    ;

  # System-parameterized builders, so a plain top-level output (not wrapped in
  # forAllSystems).
  lib = {
    inherit
      mkNixosSystem
      mkDarwinSystem
      mkNixOnDroidConfiguration
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

  # Reference configs built through the exported builders, so they exercise the
  # system-aware input selection end to end.
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

  # Standalone Home Manager configurations (Linux only: many HM modules depend
  # on Wayland/Hyprland and are not darwin-compatible; darwin home-manager is
  # tested through darwinConfigurations instead).
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
  nixOnDroidConfigurations = {
    aarch64 = mkNixOnDroidConfiguration { };
  };

  legacyPackages = mkPkgs;

  mkPackages =
    { system }:
    let
      selectedNixpkgs = (inputsFor system).nixpkgs;
      pkgs = import selectedNixpkgs {
        inherit system;
        overlays = overlayList;
      };
    in
    {
      inherit (pkgs) marchyo-wallpapers marchyo-cli;
    }
    // selectedNixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      inherit (pkgs)
        hyprmon
        marchyo-shell
        plymouth-marchyo-theme
        ;

      # NixOS VM security test: boots a Marchyo system and runs a lynis host
      # hardening audit (plus the vuls collector) inside it. Deliberately kept
      # out of `checks`: it boots a VM (needs KVM) and is run locally on demand
      # (`nix build .#security-vm-test` / `just security-vm`), not on the fast PR
      # gate. See security/vm-test.nix.
      security-vm-test = import ./security/vm-test.nix {
        inherit pkgs;
        nixosModule = nixosModules.default;
      };
    }
    // selectedNixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      inherit (pkgs) wallpapper;
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
        # nix-darwin evaluates fine on Linux, so the checks exercise the darwin
        # module set (incl. the curated HM wiring) through the same builder
        # consumers use.
        mkDarwinSystem
        ;
      nixosModules = nixosModules.default;
      homeManagerModules = homeManagerModules.default;
      nixosHardwareModules = nixosModules.hardware;
    }
    # The one non-eval check: build the Plymouth theme in both variants. The
    # only place the light variant's asset pipeline (resvg/imagemagick + the
    # package's installCheckPhase) is exercised; CI's toplevel build only bakes
    # the dark one. Plus marchyo-shell wrapper assertions and the two headless
    # shell suites (tests/shell/).
    // (
      let
        pkgs = mkPkgs system;
      in
      nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        build-plymouth-theme-dark = pkgs.plymouth-marchyo-theme;
        build-plymouth-theme-light = pkgs.plymouth-marchyo-theme.override { variant = "light"; };
        build-marchyo-shell-wrapper = pkgs.runCommand "check-marchyo-shell-wrapper" { } ''
          wrapper="${pkgs.marchyo-shell}/bin/marchyo-shell"
          grep -qE "TZDIR=.{0,15}/etc/zoneinfo" "$wrapper" \
            || { echo "FAIL: TZDIR=/etc/zoneinfo missing from marchyo-shell wrapper"; exit 1; }
          grep -qE "QT_QPA_PLATFORMTHEME=['\"]?gtk3" "$wrapper" \
            || { echo "FAIL: QT_QPA_PLATFORMTHEME=gtk3 missing from marchyo-shell wrapper"; exit 1; }
          greeter="${pkgs.marchyo-shell}/bin/marchyo-greeter"
          grep -q "share/marchyo/greeter" "$greeter" \
            || { echo "FAIL: marchyo-greeter wrapper does not point at the greeter config"; exit 1; }
          grep -qE "TZDIR=.{0,15}/etc/zoneinfo" "$greeter" \
            || { echo "FAIL: TZDIR=/etc/zoneinfo missing from marchyo-greeter wrapper"; exit 1; }
          greeterConfig="${pkgs.marchyo-shell}/share/marchyo/greeter/Commons/Config.qml"
          grep -q "nix/store" "$greeterConfig" \
            || { echo "FAIL: greeter Config.qml session command is not store-baked"; exit 1; }
          # The generator hand-writes the sessionCommand array; without commas
          # between elements it is a QML parse error, the greeter fails to load,
          # and greetd crash-loops with no login window. Assert it is
          # comma-separated.
          grep -qE 'sessionCommand:[^]]*"[^"]*",[[:space:]]*"[^"]*",[[:space:]]*"[^"]*"' "$greeterConfig" \
            || { echo "FAIL: greeter Config.qml sessionCommand array is not comma-separated (QML parse error)"; exit 1; }
          touch "$out"
        '';

        # Headless suites for the Quickshell tree. Both stage only the trees
        # they read, rather than ${./.}: the whole repo as a build input would
        # rebuild them on every site/ or docs/ edit. Each suite derives its root
        # from its own location, so the staged layout mirrors the repo's.
        shell-format-unit =
          pkgs.runCommand "check-shell-js-unit"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            }
            ''
              mkdir -p src/shell src/tests
              cp -r ${./shell/Commons} src/shell/Commons
              cp -r ${./tests/shell} src/tests/shell
              cd src
              node tests/shell/format-test.js
              node tests/shell/notify-test.js
              node tests/shell/launcher-test.js
              node tests/shell/peripherals-test.js
              touch "$out"
            '';

        # site/src/pages/search.astro's option table is hand-maintained with no
        # generator, so nothing stops it drifting from the options tree. This is
        # the guard.
        site-option-paths =
          pkgs.runCommand "check-site-option-paths"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            }
            ''
              # Only the parents: `cp -r dir target` nests when target exists.
              mkdir -p src/tests src/site/src
              cp -r ${./tests/site} src/tests/site
              cp -r ${./site/src/pages} src/site/src/pages
              cp -r ${./modules} src/modules
              cd src
              node tests/site/option-paths-test.js
              touch "$out"
            '';

        shell-contracts =
          pkgs.runCommand "check-shell-contracts"
            {
              nativeBuildInputs = [
                pkgs.gnugrep
                pkgs.gawk
              ];
            }
            ''
              mkdir -p src/tests src/packages
              cp -r ${./shell} src/shell
              cp -r ${./greeter} src/greeter
              cp -r ${./modules} src/modules
              cp -r ${./packages/marchyo-shell} src/packages/marchyo-shell
              cp -r ${./tests/shell} src/tests/shell
              cd src
              bash tests/shell/contracts-test.sh
              touch "$out"
            '';
      }
    );

  mkFormatter =
    { system }:
    let
      pkgs = (inputsFor system).nixpkgs.legacyPackages.${system};
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

      # Reference system closure the SBOM / vulnerability scanners target by
      # default (same build as nixosConfigurations.x86_64). Interpolated into the
      # scanner scripts, so `nix run .#sbom` builds it; `nix flake check` only
      # evaluates it.
      refToplevel =
        (mkNixosSystem {
          inherit system;
          modules = [
            sharedNixosConfig
            { networking.hostName = "marchyo-x86-64"; }
          ];
        }).config.system.build.toplevel;

      sbomApp = import ./security/sbom.nix {
        inherit pkgs;
        defaultTarget = refToplevel;
      };
      vulnScanApp = import ./security/vuln-scan.nix {
        inherit pkgs;
        defaultTarget = refToplevel;
      };
    in
    {
      default = {
        type = "app";
        program = "${runner}/bin/run-vm";
        meta.description = "Run a QEMU VM with all Marchyo features enabled";
      };

      # Supply-chain / vulnerability tooling, run on the host against the real
      # system closure (they query the Nix store and fetch CVE data online, so
      # they can't be hermetic checks). See security/sbom.nix, security/vuln-scan.nix.
      sbom = {
        type = "app";
        program = "${sbomApp}/bin/marchyo-sbom";
        meta.description = "Generate a CycloneDX/SPDX SBOM of the reference Marchyo system (sbomnix)";
      };
      vuln-scan = {
        type = "app";
        program = "${vulnScanApp}/bin/marchyo-vuln-scan";
        meta.description = "Scan the reference Marchyo system closure for known CVEs (vulnxscan + vulnix; needs network)";
      };
    };
}
