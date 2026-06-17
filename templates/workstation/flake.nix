{
  description = "Marchyo Developer Workstation Configuration";

  inputs = {
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs =
    { marchyo, ... }:
    {
      # marchyo.lib.mkNixosSystem selects the correct nixpkgs (unstable),
      # home-manager, stylix, overlay and marchyo modules automatically — you
      # supply only your own config module.
      nixosConfigurations.workstation = marchyo.lib.mkNixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit marchyo;
        };
      };

      # On x86_64-darwin, mkDarwinSystem transparently pins the stable
      # nixos-26.05 set (26.05 is the last release supporting Intel macOS);
      # aarch64-darwin rides unstable. Either way you write only ./darwin.nix:
      #
      # darwinConfigurations.mac = marchyo.lib.mkDarwinSystem {
      #   system = "x86_64-darwin";
      #   modules = [ ./darwin.nix ];
      #   specialArgs = { inherit marchyo; };
      # };
    };
}
