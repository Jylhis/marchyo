{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs =
    {
      nixpkgs,
      marchyo,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        workstation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            marchyo.nixosModules.default
            ./configuration.nix
          ];
          specialArgs = {
            inherit inputs;
          };
        };
      };
    };
}
