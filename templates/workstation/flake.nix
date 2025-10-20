{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    # nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    marchyo = {
      url = "git+file:///home/markus/Developer/marchyo";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Determinate Nix
    # determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    # fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";

    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1.*";

    # home-manager = {
    # url = "https://flakehub.com/f/nix-community/home-manager/0.1.*";
    # inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    # https://flake.parts/module-arguments.html
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, inputs, ... }:
      {
        systems = [
          "x86_64-linux"
          # "aarch64-linux"
        ];
        imports = [
          inputs.marchyo.flakeModules.default
        ];

        flake = {
          nixosConfigurations = {

            workstation = withSystem "x86_64-linux" (
              { inputs', ... }:
              inputs.marchyo.lib.marchyo.mkNixosSystem {
                system = "x86_64-linux";
                modules = [
                  # inputs.marchyo.diskoConfigurations.btrfs
                  ./configuration.nix
                ];
                extraSpecialArgs = {
                  inherit inputs';
                };
              }
            );
          };
        };

        # Example of using Marchyo helpers in perSystem
        # See docs/HELPERS.md for comprehensive documentation
        perSystem =
          { marchyo, ... }:
          {
            # Expose Marchyo's custom packages
            packages = {
              inherit (marchyo.packages) plymouth-marchyo-theme hyprmon;

              # Build a VM for testing
              vm = marchyo.builders.vm "workstation";

              # Build the full system
              system = marchyo.builders.toplevel "workstation";
            };

            # Use the pre-configured development shell
            devShells.default = marchyo.devShells.default;

            # Useful apps for system management
            apps = {
              show = marchyo.apps.show-systems;
              vm = marchyo.apps.build-vm;
              colors = marchyo.apps.list-colorschemes;
            };
          };
      }
    );
}
