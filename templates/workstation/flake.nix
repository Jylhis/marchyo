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
              inputs.marchyo.lib.nixosSystem {
                specialArgs = {

                  inherit inputs inputs';
                };
                modules = [
                  inputs.marchyo.nixosModules.default
                  inputs.marchyo.diskoConfigurations.btrfs
                  ./configuration.nix
                ];
              }
            );
          };
        };
      }
    );
  # {
  #   nixpkgs,
  #   marchyo,
  #   ...
  # }:
  # {

  # };
}
