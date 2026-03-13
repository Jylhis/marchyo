{
  pkgs ? import <nixpkgs> { },
}:
let
  eval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    modules = [
      {
        services.pipewire.enable = true;
        system.stateVersion = "23.11";
      }
    ];
  };
in
eval.config.services.pipewire.wireplumber.enable
