{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs =
    { marchyo, ... }:
    {
      nixosConfigurations = {
        workstation = marchyo.lib.marchyo.mkNixosSystem {
          system = "x86_64-linux";
          modules = [
            # marchyo.diskoConfigurations.btrfs
            ./configuration.nix
          ];
          extraSpecialArgs = {
            # Add any extra arguments here
          };
        };
      };
    };
}
