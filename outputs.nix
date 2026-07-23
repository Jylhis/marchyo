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
    noctalia
    stylix
    stylix-stable
    sops-nix
    llm-agents
    jotain
    treefmt-nix
    ;

  overlay = import ./overlay.nix { inherit inputs; };

  # marchyo's overlay plus llm-agents.nix (exposes pkgs.llm-agents.<agent>,
  # e.g. claude-code, from its Numtide-cached pinned set). Upstream dropped its
  # `overlays.default` output, so we build the equivalent overlay here from the
  # per-system `packages` set. The attr is lazy and guarded with `or { }`, so
  # systems llm-agents doesn't build for (x86_64-darwin) only fail if something
  # actually reads `pkgs.llm-agents`.
  llmAgentsOverlay = _final: prev: {
    llm-agents = llm-agents.packages.${prev.stdenv.hostPlatform.system} or { };
  };

  overlayList = [
    overlay
    llmAgentsOverlay
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

  # Droid input stack — the nix-on-droid analog of `inputsFor`. Pinned
  # independently of the unstable/stable selector: nix-on-droid's own
  # (2024-era) nixpkgs paired with the HM-24.05 `home-manager-droid`. This is
  # the single place the droid stack is chosen; `mkNixOnDroidConfiguration`
  # flows through it.
  droidInputs = {
    nixpkgs = nix-on-droid.inputs.nixpkgs;
    home-manager = home-manager-droid;
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
      # Bash is the marchyo default login shell on every platform (zsh stays
      # installed and configured as an alternative — see modules/nix-on-droid).
      user.shell = "${pkgs.bashInteractive}/bin/bash";
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
        jotain.homeManagerModules.default
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
        jotain.homeManagerModules.default
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
    # Per-machine hardware fixes: the complete nixos-hardware profile set,
    # re-exported wholesale as a thin passthrough (profiles are lazy — unused
    # ones cost nothing). A host imports its profile directly, e.g.:
    #
    #   imports = [ marchyo.nixosModules.hardware.lenovo-thinkpad-x1-9th-gen ];
    #
    # Curated examples live in templates/workstation and docs/introduction.mdx,
    # pinned by tests/eval/hardware.nix. Full list:
    # https://github.com/NixOS/nixos-hardware
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

  # nix-on-droid builder. The droid analog of mkNixosSystem/mkDarwinSystem,
  # fixed to aarch64-linux (the only Android target). Inputs flow through
  # `droidInputs`; `nixOnDroidModules.default` + `sharedNixOnDroidConfig` are
  # baked in, exactly as the NixOS/darwin builders bake in their module sets.
  #
  # The marchyo overlay is NOT forced on (it is Linux-desktop-shaped); overlays
  # default to [] and a consumer can opt in. The droid stack stays on HM 24.05,
  # so the marchyo HM modules (modules/home/*) and the marchyo.* options
  # namespace remain out of scope — the droid modules reuse only the
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
  # Build-time data generator for the website's package/option search
  # (site/src/pages/search.astro). Produces a directory with two JSON files:
  #
  #   options.json          — every `marchyo.*` NixOS option, extracted from the
  #                           declarations via `nixosOptionsDoc` (rendered type /
  #                           default / example / description) with declaration
  #                           paths rewritten to repo-relative + GitHub blob URLs.
  #   marchyo-packages.json — pname/version/meta for marchyo's own packages.
  #
  # The output is committed under site/src/data/ (the Cloudflare build runs bun
  # only, no Nix) via `just site-data`, and a CI gate re-runs this and fails on a
  # diff. nixpkgs (all-of-nixpkgs) search is served separately by the D1-backed
  # Worker; this generator only covers marchyo's own options and packages.
  mkSiteSearchData =
    { system }:
    let
      selectedNixpkgs = (inputsFor system).nixpkgs;
      inherit (selectedNixpkgs) lib;
      pkgs = mkPkgs system;

      # Evaluate ONLY the marchyo option declarations (modules/nixos/options),
      # not the full nixosModules.default — the option files are declaration-only
      # and depend on nothing but lib/pkgs and other marchyo.* options, so this
      # skips the entire NixOS + home-manager + stylix option universe and keeps
      # nixosOptionsDoc fast. `_module.check = false` tolerates the reduced arg
      # set. (This is the NuschtOS/search generation approach.)
      eval = lib.evalModules {
        specialArgs = { inherit pkgs lib; };
        modules = [
          ./modules/nixos/options
          { config._module.check = false; }
        ];
      };

      # The flake source in the store; used to rewrite absolute declaration
      # paths (e.g. /nix/store/HASH-source/modules/nixos/options/theme.nix) back
      # to repo-relative paths + GitHub blob URLs. Non-marchyo declarations
      # (home-manager, stylix, …) keep their store path and are filtered out by
      # the jq `startswith("marchyo.")` selection below, so their URLs never ship.
      srcPrefix = "${toString ./.}/";
      gitBlob = "https://github.com/Jylhis/marchyo/blob/main/";

      optionsDoc = pkgs.nixosOptionsDoc {
        inherit (eval) options;
        warningsAreErrors = false;
        transformOptions =
          opt:
          opt
          // {
            declarations = map (
              decl:
              let
                declStr = toString decl;
              in
              if lib.hasPrefix srcPrefix declStr then
                let
                  rel = lib.removePrefix srcPrefix declStr;
                in
                {
                  name = rel;
                  url = gitBlob + rel;
                }
              else
                decl
            ) opt.declarations;
          };
      };

      # marchyo's own packages (the overlay/mkPackages set), reduced to the
      # metadata the search UI shows. Optional meta fields are guarded with `or`.
      pkgSet = {
        inherit (pkgs) marchyo-wallpapers marchyo-cli;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        inherit (pkgs)
          hyprmon
          plymouth-marchyo-theme
          openviking
          pi
          ;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        inherit (pkgs) wallpapper;
      };

      renderLicense =
        l:
        if l == null then
          ""
        else if lib.isList l then
          lib.concatMapStringsSep ", " (x: x.spdxId or x.shortName or "") l
        else
          l.spdxId or l.shortName or "";

      pkgRows = lib.sort (a: b: a.name < b.name) (
        lib.mapAttrsToList (attr: p: {
          inherit attr;
          name = p.pname or (lib.getName p);
          version = p.version or "";
          description = p.meta.description or "";
          homepage = p.meta.homepage or "";
          license = renderLicense (p.meta.license or null);
          mainProgram = p.meta.mainProgram or "";
          source = "marchyo";
        }) pkgSet
      );

      # jq filter: keep marchyo.* options, reshape to the row shape search.astro
      # consumes. render() flattens nixosOptionsDoc's {_type,text} wrappers.
      optionsFilter = ''
        def render(v): if v == null then "" elif (v|type)=="object" then (v.text // "") else (v|tostring) end;
        [ to_entries[]
          | select(.key | startswith("marchyo."))
          | { name: .key,
              type: (.value.type // ""),
              default: render(.value.default),
              example: render(.value.example),
              description: ((.value.description // "") | gsub("\\s+$"; "")),
              declared: (.value.declarations[0].name // ""),
              url: (.value.declarations[0].url // "") }
        ]
      '';
    in
    pkgs.runCommand "marchyo-site-search-data"
      {
        nativeBuildInputs = [ pkgs.jq ];
        passAsFile = [ "pkgsJson" ];
        pkgsJson = builtins.toJSON pkgRows;
      }
      ''
        mkdir -p "$out"
        jq -S '${optionsFilter}' \
          ${optionsDoc.optionsJSON}/share/doc/nixos/options.json \
          > "$out/options.json"
        jq -S '.' "$pkgsJsonPath" > "$out/marchyo-packages.json"
      '';
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

  # nix-on-droid (Android terminal), built through the same exported builder
  # consumers use. Build with:
  #   nix build .#nixOnDroidConfigurations.aarch64.activationPackage
  # Kept internally consistent on nix-on-droid's own (2024) nixpkgs + HM 24.05;
  # the marchyo overlay is intentionally NOT applied (overlays default to []).
  nixOnDroidConfigurations = {
    aarch64 = mkNixOnDroidConfiguration { };
  };

  # System-aware: x86_64-darwin → stable nixos-26.05, every other system →
  # unstable. Always with marchyo's overlay applied and unfree allowed.
  legacyPackages = mkPkgs;

  mkPackages =
    { system }:
    let
      # x86_64-darwin rides stable 26.05 (unstable 26.11 dropped it) — same
      # per-system selector as legacyPackages/the builders.
      selectedNixpkgs = (inputsFor system).nixpkgs;
      pkgs = import selectedNixpkgs {
        inherit system;
        overlays = overlayList;
      };
    in
    {
      inherit (pkgs) marchyo-wallpapers marchyo-cli;
    }
    // selectedNixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
      inherit (pkgs)
        hyprmon
        plymouth-marchyo-theme
        openviking
        pi
        ;
      site-search-data = mkSiteSearchData { inherit system; };
    }
    // selectedNixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
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
    };

  mkFormatter =
    { system }:
    let
      # x86_64-darwin rides stable 26.05 (unstable 26.11 dropped it).
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
    in
    {
      default = {
        type = "app";
        program = "${runner}/bin/run-vm";
        meta.description = "Run a QEMU VM with all Marchyo features enabled";
      };
    };
}
