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
      # marchyo.lib.mkNixosSystem selects the correct nixpkgs (unstable),
      # home-manager, overlay and marchyo modules automatically — you
      # supply only your own config module.
      nixosConfigurations.workstation = marchyo.lib.mkNixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit inputs marchyo;
        };
      };
    };
}
