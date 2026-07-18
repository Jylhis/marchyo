{
  description = "Marchyo";

  inputs = {
    # Primary nixpkgs: unstable. Most outputs ride this. The stable 26.05 set
    # below is used only by darwinConfigurations.x86_64.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    # nix-darwin / home-manager / stylix track master so they pair with the
    # unstable primary nixpkgs (release branches assume their matching nixpkgs).
    # darwinConfigurations.x86_64 instead pins its package set to nixos-26.05,
    # so it uses the matching *-stable release-branch inputs below — nix-darwin
    # enforces this with a hard build assertion, home-manager with a warning.
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Stable nix-darwin (nix-darwin-26.05) to pair with nixpkgs-stable for
    # darwinConfigurations.x86_64. Must NOT follow the unstable primary.
    nix-darwin-stable = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Stable home-manager (release-26.05) to pair with nixpkgs-stable. Used only
    # by darwinConfigurations.x86_64, which pins its package set to nixos-26.05
    # (the last nixpkgs release supporting x86_64-darwin). Must NOT follow the
    # unstable primary — release branches assume their matching nixpkgs.
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Stable stylix (release-26.05) to pair with nixpkgs-stable for
    # darwinConfigurations.x86_64. Must NOT follow the unstable primary.
    stylix-stable = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    # nix-on-droid (Android terminal). Pinned to the latest prerelease with a
    # dedicated home-manager input matching it (the prerelease expects HM 24.05).
    # Kept internally consistent on its own bundled nixpkgs — NOT following the
    # unstable primary — so the droid HM config stays on HM-24.05 semantics.
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/prerelease-25.11";
      inputs.home-manager.follows = "home-manager-droid";
    };
    # Pinned to the exact home-manager revision nix-on-droid prerelease-25.11
    # bundles, so it matches that branch's (2024-era) nixpkgs lib. Using
    # release-24.05 HEAD instead breaks: its kanshi.nix needs lib.types.attrTag,
    # absent from the bundled nixpkgs.
    home-manager-droid = {
      url = "github:nix-community/home-manager/4de84265d7ec7634a69ba75028696d74de9a44a7";
      inputs.nixpkgs.follows = "nix-on-droid/nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jylhis-design = {
      url = "github:Jylhis/design";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Jotain — Jylhis's Emacs config, distributed as a flake. Its
    # homeManagerModules.default is self-contained (extends pkgs with its own
    # overlay internally), so only nixpkgs needs to follow. Wired in as the
    # `marchyo.defaults.editor`/`terminalEditor = "jotain"` implementation.
    # The nested jylhis-emacs.nixpkgs follows ours too: otherwise that pinned
    # (non-following) nixpkgs lands an extra rev in the closure and gets the
    # bare `nixpkgs` lock-node name, diverging the flake.lock/devenv.lock
    # nixpkgs-rev parity check (CI `verify`).
    jotain = {
      url = "github:Jylhis/jotain";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.jylhis-emacs.inputs.nixpkgs.follows = "nixpkgs";
    };
    # AI coding agents (claude-code, codex, gemini-cli, goose, …), daily-updated
    # with the Numtide binary cache. Intentionally NOT following nixpkgs: its
    # overlays.default is pinned so cache.numtide.com substitutes prebuilt
    # binaries (following nixpkgs would force local rebuilds).
    llm-agents.url = "github:numtide/llm-agents.nix";
    wallpapper-src = {
      url = "github:mczachurski/wallpapper/1.7.4";
      flake = false;
    };

  };

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      marchyo = import ./outputs.nix { inherit inputs; };
      systems = import ./lib/systems.nix;
      forLinuxSystems = nixpkgs.lib.genAttrs systems.linux;
      forAllSystems = nixpkgs.lib.genAttrs systems.all;
    in
    {
      inherit (marchyo)
        nixosModules
        darwinModules
        homeManagerModules
        nixOnDroidModules
        nixosConfigurations
        darwinConfigurations
        homeConfigurations
        nixOnDroidConfigurations
        overlays
        templates
        lib
        ;
      legacyPackages = forAllSystems marchyo.legacyPackages;
      packages = forAllSystems (system: marchyo.mkPackages { inherit system; });
      checks = forLinuxSystems (system: marchyo.mkChecks { inherit system; });
      formatter = forAllSystems (system: marchyo.mkFormatter { inherit system; });
      apps = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system: marchyo.mkApps { inherit system; });
    };
}
