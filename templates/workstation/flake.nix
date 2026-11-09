{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs =
    { marchyo, ... }:
    {
      # marchyo.lib.mkNixosSystem selects the correct nixpkgs (unstable),
      # home-manager, overlay and marchyo modules automatically — you
      # supply only your own config module.
      nixosConfigurations.workstation = marchyo.lib.mkNixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit marchyo;
        };
      };

      # nix-on-droid (Android terminal, aarch64). mkNixOnDroidConfiguration
      # bakes in the droid stack (nix-on-droid's nixpkgs + HM 24.05); you supply
      # only your own droid module. Build with:
      #   nix build --impure .#nixOnDroidConfigurations.phone.activationPackage
      #
      # nixOnDroidConfigurations.phone = marchyo.lib.mkNixOnDroidConfiguration {
      #   modules = [ ./droid.nix ];
      # };
    };
}
