{ config, lib, ... }:
let
  cfg = config.marchyo.nix;
  listen = "http://localhost:${toString cfg.router.port}";
in
{
  config = lib.mkIf cfg.router.enable {
    services.ncro = {
      enable = true;
      # Appends each upstream's public_key to nix.settings.trusted-public-keys.
      # Additive, so it coexists with the keys nix-settings.nix already sets from
      # marchyo.nix.caches (Nix dedups).
      addUpstreamPublicKeys = true;
      netrcFile = lib.mkIf (cfg.router.netrcFile != null) cfg.router.netrcFile;
      settings = {
        server.listen = ":${toString cfg.router.port}";
        upstreams =
          # marchyo caches, carrying their public_key when signed.
          map (
            c: { inherit (c) url; } // lib.optionalAttrs (c.publicKey != null) { public_key = c.publicKey; }
          ) cfg.caches
          # plus extra upstreams (default: cache.nixos.org).
          ++ map (u: { url = u; }) cfg.router.extraUpstreams;
      };
    };

    # Front the caches with ncro: prepend the local proxy, keep every cache in
    # marchyo.nix.caches as a direct fallback (mkBefore, not mkForce). Nix dedups
    # and routes by priority, so the localhost entry simply wins.
    nix.settings.substituters = lib.mkBefore [ "${listen}?priority=0" ];
  };
}
