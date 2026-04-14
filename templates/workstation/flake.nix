{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs =
    { marchyo, ... }:
    let
      inherit (marchyo.inputs) nixpkgs;
    in
    {
      nixosConfigurations = {
        workstation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            marchyo.nixosModules.default
            ./configuration.nix
          ];
          specialArgs = {
            inherit marchyo;
          };
        };
      };
    };
}
