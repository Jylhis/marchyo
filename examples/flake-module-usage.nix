# Example usage of the marchyo flake module
# This file demonstrates how users can leverage the flake-parts integration

{
  description = "Example using marchyo flake module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:yourusername/marchyo";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Import the marchyo flake module
        inputs.marchyo.flakeModules.default
      ];

      # Define your systems using the declarative API
      flake.marchyo.systems = {
        # This will automatically generate nixosConfigurations.workstation
        workstation = {
          system = "x86_64-linux";
          modules = [
            ./hardware-configuration.nix
            {
              # Enable marchyo features
              marchyo.desktop.enable = true;
              marchyo.users.myuser = {
                enable = true;
                fullname = "My Name";
                email = "myemail@example.com";
              };
            }
          ];
        };

        # Another system with custom hostname
        server = {
          system = "x86_64-linux";
          hostname = "prod-server-01";
          modules = [
            ./server-hardware.nix
            {
              marchyo.server.enable = true;
            }
          ];
        };

        # System with manual configuration (won't auto-generate)
        custom-system = {
          system = "x86_64-linux";
          autoGenerate = false; # Manage manually in flake.nixosConfigurations
          modules = [ ./custom.nix ];
        };
      };

      # The marchyo module automatically:
      # - Generates nixosConfigurations.workstation
      # - Generates nixosConfigurations.server (with hostname prod-server-01)
      # - Passes inputs and inputs' to all modules via specialArgs
      # - Includes marchyo's default modules (home-manager, disko, etc.)

      # Helper functions are available in perSystem
      perSystem =
        { marchyo, ... }:
        {
          # Access marchyo helpers
          packages = {
            # Build a test VM for the workstation
            test-workstation = marchyo.mkTestVm "workstation";

            # Build all systems at once
            inherit (marchyo.buildAllSystems) workstation server;
          };

          # Check if a system is configured
          devShells.default =
            if marchyo.hasSystem "workstation" then
              # ...
              null
            else
              null;
        };
    };
}
