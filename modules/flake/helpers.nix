# Helper functions exposed in perSystem for convenience
# Provides marchyo.* helpers when enabled
{ localFlake }:
{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (localFlake) withSystem;

  cfg = config.flake.marchyo;
in
{
  # Always provide marchyo perSystem helpers
  # mkIf would cause infinite recursion when checking cfg.helpers.enable
  config.perSystem =
    {
      system,
      pkgs,
      ...
    }:
    {
      marchyo = mkIf cfg.helpers.enable {
        # ========================================
        # LIBRARY AND INPUTS ACCESS
        # ========================================

        # Expose the extended marchyo lib in perSystem
        lib = config.flake.lib.marchyo or { };

        # Provide inputs' helper for current system
        # This mirrors what's available in specialArgs
        inputs' = withSystem system ({ inputs', ... }: inputs');

        # ========================================
        # CUSTOM PACKAGES
        # ========================================

        packages = {
          # Plymouth boot theme for Marchyo
          # Usage: marchyo.packages.plymouth-marchyo-theme
          plymouth-marchyo-theme = pkgs.callPackage ../../packages/plymouth-marchyo-theme/package.nix { };

          # Hyprland monitor configuration TUI tool
          # Usage: marchyo.packages.hyprmon
          hyprmon = pkgs.callPackage ../../packages/hyprmon/package.nix { };
        };

        # ========================================
        # ADVANCED BUILDERS
        # ========================================

        builders = {
          # Build a VM for testing a nixosConfiguration
          # Usage: marchyo.builders.vm "workstation"
          # Returns: derivation for the VM runner script
          vm =
            systemName:
            let
              nixosConfig = config.flake.nixosConfigurations.${systemName} or null;
            in
            if nixosConfig == null then
              throw "System '${systemName}' not found in nixosConfigurations. Available systems: ${lib.concatStringsSep ", " (lib.attrNames config.flake.nixosConfigurations)}"
            else
              nixosConfig.config.system.build.vm;

          # Build a VM with disko disk setup
          # Usage: marchyo.builders.vmWithDisko "workstation"
          # Returns: derivation for the VM with disk configuration
          vmWithDisko =
            systemName:
            let
              nixosConfig = config.flake.nixosConfigurations.${systemName} or null;
            in
            if nixosConfig == null then
              throw "System '${systemName}' not found in nixosConfigurations. Available systems: ${lib.concatStringsSep ", " (lib.attrNames config.flake.nixosConfigurations)}"
            else if !(nixosConfig.config.system.build ? vmWithDisko) then
              throw "System '${systemName}' does not have disko configured. Make sure disko is imported in the system configuration."
            else
              nixosConfig.config.system.build.vmWithDisko;

          # Build an ISO installer image
          # Usage: marchyo.builders.iso "workstation"
          # Returns: derivation for the ISO image
          iso =
            systemName:
            let
              nixosConfig = config.flake.nixosConfigurations.${systemName} or null;
            in
            if nixosConfig == null then
              throw "System '${systemName}' not found in nixosConfigurations. Available systems: ${lib.concatStringsSep ", " (lib.attrNames config.flake.nixosConfigurations)}"
            else if !(nixosConfig.config.system.build ? isoImage) then
              throw "System '${systemName}' does not have ISO image configured. You need to import an ISO profile (like nixos/modules/installer/cd-dvd/installation-cd-minimal.nix)."
            else
              nixosConfig.config.system.build.isoImage;

          # Build the toplevel system derivation
          # Usage: marchyo.builders.toplevel "workstation"
          # Returns: derivation for the full system
          toplevel =
            systemName:
            let
              nixosConfig = config.flake.nixosConfigurations.${systemName} or null;
            in
            if nixosConfig == null then
              throw "System '${systemName}' not found in nixosConfigurations. Available systems: ${lib.concatStringsSep ", " (lib.attrNames config.flake.nixosConfigurations)}"
            else
              nixosConfig.config.system.build.toplevel;
        };

        # ========================================
        # COLOR SCHEMES
        # ========================================

        # All available color schemes (nix-colors + custom)
        # Usage: marchyo.colorSchemes.dracula
        # Usage: marchyo.colorSchemes.modus-vivendi-tinted
        colorSchemes = inputs.nix-colors.colorSchemes // (import ../../colorschemes);

        # ========================================
        # DEVELOPMENT SHELLS
        # ========================================

        devShells = {
          # Default development shell with useful tools for working with marchyo
          # Usage: nix develop .#marchyo-dev
          # Or in perSystem: devShells.default = marchyo.devShells.default;
          default = pkgs.mkShell {
            name = "marchyo-dev";

            buildInputs = with pkgs; [
              # Nix tools
              nix
              nixfmt-rfc-style
              nixpkgs-fmt
              nil # Nix language server
              nix-tree
              nix-diff
              nvd # Nix version diff tool

              # Git and development tools
              git
              gh # GitHub CLI

              # Formatting and linting
              treefmt
              shellcheck
              actionlint
              deadnix
              statix
              yamlfmt

              # Utilities
              jq
              ripgrep
              fd
            ];

            shellHook = ''
              echo "🚀 Marchyo development environment"
              echo ""
              echo "Available commands:"
              echo "  nix flake check      - Validate flake configuration"
              echo "  nix fmt              - Format all Nix files"
              echo "  nix flake show       - Show flake outputs"
              echo ""
              echo "Available systems:"
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''echo "  - ${name}"'') cfg.systems)}
              echo ""
            '';
          };
        };

        # ========================================
        # UTILITY APPS
        # ========================================

        apps = {
          # Show all configured systems with their details
          # Usage: nix run .#show-systems
          show-systems = {
            type = "app";
            program =
              let
                script = pkgs.writeShellScriptBin "show-systems" ''
                  echo "📦 Configured NixOS Systems:"
                  echo ""
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: systemCfg: ''
                      echo "System: ${name}"
                      echo "  Architecture: ${systemCfg.system or "unknown"}"
                      echo "  Hostname: ${systemCfg.config.networking.hostName or "unknown"}"
                      echo "  Users: ${lib.concatStringsSep ", " (lib.attrNames (systemCfg.config.users.users or { }))}"
                      echo ""
                    '') (config.flake.nixosConfigurations or { })
                  )}
                '';
              in
              "${script}/bin/show-systems";
          };

          # Build and run a VM for a system
          # Usage: nix run .#build-vm workstation
          build-vm = {
            type = "app";
            program =
              let
                script = pkgs.writeShellScriptBin "build-vm" ''
                  if [ -z "$1" ]; then
                    echo "Usage: $0 <system-name>"
                    echo ""
                    echo "Available systems:"
                    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''echo "  - ${name}"'') cfg.systems)}
                    exit 1
                  fi

                  SYSTEM="$1"
                  echo "Building VM for system: $SYSTEM"
                  nix build ".#nixosConfigurations.$SYSTEM.config.system.build.vm" --print-out-paths

                  echo ""
                  echo "To run the VM, execute:"
                  echo "  ./result/bin/run-*-vm"
                '';
              in
              "${script}/bin/build-vm";
          };

          # List all available color schemes
          # Usage: nix run .#list-colorschemes
          list-colorschemes = {
            type = "app";
            program =
              let
                script = pkgs.writeShellScriptBin "list-colorschemes" ''
                  echo "🎨 Available Color Schemes:"
                  echo ""
                  echo "Custom Marchyo schemes:"
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: _: ''
                      echo "  - ${name}"
                    '') (import ../../colorschemes)
                  )}
                  echo ""
                  echo "From nix-colors (${toString (lib.length (lib.attrNames inputs.nix-colors.colorSchemes))} schemes):"
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: _: ''
                      echo "  - ${name}"
                    '') inputs.nix-colors.colorSchemes
                  )}
                '';
              in
              "${script}/bin/list-colorschemes";
          };
        };

        # ========================================
        # LEGACY HELPERS (maintained for compatibility)
        # ========================================

        # Helper to build a test VM for a specific system
        # DEPRECATED: Use marchyo.builders.vm instead
        # Note: This is a function that returns a derivation, evaluation is lazy
        mkTestVm = systemName: config.flake.nixosConfigurations.${systemName}.config.system.build.vm;

        # Helper to build all configured systems
        # Note: This is an attrset of derivations, evaluation is lazy
        buildAllSystems = lib.mapAttrs (
          name: _: config.flake.nixosConfigurations.${name}.config.system.build.toplevel
        ) cfg.systems;

        # Helper to get system configuration by name
        getSystemConfig = systemName: cfg.systems.${systemName} or null;

        # Helper to check if a system is configured
        hasSystem = systemName: cfg.systems ? ${systemName};
      };
    };
}
