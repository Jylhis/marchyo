{
  description = "My Marchyo NixOS Configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    marchyo = {
      url = "github:marchyo/marchyo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      marchyo,
      ...
    }:
    {
      nixosConfigurations.my-system = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          marchyo.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
