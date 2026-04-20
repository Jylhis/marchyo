{ config, lib, ... }:
{
  nix = {
    settings = {
      trusted-users = [ "@wheel" ] ++ (builtins.attrNames config.marchyo.users);
      tarball-ttl = lib.mkDefault 604800;
      download-buffer-size = lib.mkDefault "256M";
      builders-use-substitutes = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://jylhis.cachix.org"
        "https://nix-community.cachix.org"
        "https://vicinae.cachix.org"
        "https://devenv.cachix.org"
        "https://numtide.cachix.org"
        "https://hyprland.cachix.org"
        "https://cache.numtide.com"
      ];
      trusted-substituters = [
        "https://jylhis.cachix.org"
        "https://nix-community.cachix.org"
        "https://vicinae.cachix.org"
        "https://devenv.cachix.org"
        "https://numtide.cachix.org"
        "https://hyprland.cachix.org"
        "https://cache.numtide.com"
      ];
      trusted-public-keys = [
        "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
  };
}
