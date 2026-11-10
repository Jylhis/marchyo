{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    marchyo.url = "github:Jylhis/marchyo";
    # Optional per-machine hardware profiles, see configuration.nix:
    # nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    inputs@{ marchyo, ... }:
    {
      # mkNixosSystem brings nixpkgs, Home Manager, the overlay and the
      # marchyo modules; supply only your own modules.
      nixosConfigurations.workstation = marchyo.lib.mkNixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit inputs marchyo;
        };
      };
    };
}
