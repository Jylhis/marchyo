{ config, lib, ... }:
{
  nix = {
    settings = {
      trusted-users = [ "@wheel" ] ++ (builtins.attrNames config.marchyo.users);
      tarball-ttl = lib.mkDefault 604800;
      download-buffer-size = lib.mkDefault "256M";
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://jylhis.cachix.org"
        "https://nix-community.cachix.org"
        "https://vicinae.cachix.org"
      ];
      trusted-substituters = [
        "https://jylhis.cachix.org"
        "https://nix-community.cachix.org"
        "https://vicinae.cachix.org"
      ];
      trusted-public-keys = [
        "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      ];
    };
  };
}
