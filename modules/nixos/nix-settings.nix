{ lib, ... }:
{
  nix = {
    # gc.automatic = lib.mkDefault true;
    # optimise.automatic = lib.mkDefault true;

    settings = {
      accept-flake-config = true;
      trusted-users = [ "@wheel" ];
      tarball-ttl = lib.mkDefault 604800;
      download-buffer-size = lib.mkDefault "256M";
      experimental-features = [
        "nix-command"
        "flakes"
        "ca-derivations"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://marchyo.cachix.org"
      ];
      trusted-substituters = [
        "https://nix-community.cachix.org"
        "https://marchyo.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "marchyo.cachix.org-1:qltBYn5yeoPg4kerXOzZi9NHzUlu1PCOBaol/FzdiGY="
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;
}
