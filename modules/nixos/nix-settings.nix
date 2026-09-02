{ config, lib, ... }:
let
  cfg = config.marchyo.nix;
  # Single source of truth: derive the substituter and key lists from
  # marchyo.nix.caches so a cache is declared exactly once (and the ncro
  # router can consume the same list). See modules/nixos/options/nix-cache.nix.
  cacheUrls = map (c: c.url) cfg.caches;
  cacheKeys = lib.filter (k: k != null) (map (c: c.publicKey) cfg.caches);
in
{
  nix = {
    settings = {
      trusted-users = [
        "@wheel"
      ]
      ++ lib.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
      tarball-ttl = lib.mkDefault 604800;
      download-buffer-size = lib.mkDefault "256M";
      builders-use-substitutes = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = cacheUrls;
      trusted-substituters = cacheUrls;
      trusted-public-keys = cacheKeys;
    };
  };
}
