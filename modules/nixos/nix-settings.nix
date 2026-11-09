# Global (headless-safe): nix daemon settings, store cleanup and optimisation.
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
      # The daemon frees space mid-build: collect down to max-free once less than min-free remains.
      min-free = lib.mkDefault (10 * 1024 * 1024 * 1024);
      max-free = lib.mkDefault (50 * 1024 * 1024 * 1024);
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
    optimise.automatic = lib.mkDefault true;
  };

  # Hosts that schedule nix.gc themselves keep it; the rest get nh.
  programs.nh = lib.mkIf (!config.nix.gc.automatic) {
    enable = lib.mkDefault true;
    clean = {
      enable = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      extraArgs = lib.mkDefault "--keep 10 --keep-since 14d";
    };
  };
}
