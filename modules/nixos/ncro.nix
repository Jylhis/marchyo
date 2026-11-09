{ config, lib, ... }:
let
  cfg = config.marchyo.nix;
  listen = "http://localhost:${toString cfg.router.port}";
in
{
  config = lib.mkIf cfg.router.enable {
    services.ncro = {
      enable = lib.mkDefault true;
      # Appends each upstream's public_key to nix.settings.trusted-public-keys.
      # Additive, so it coexists with the keys nix-settings.nix already sets from
      # marchyo.nix.caches (Nix dedups).
      addUpstreamPublicKeys = true;
      netrcFile = lib.mkIf (cfg.router.netrcFile != null) cfg.router.netrcFile;
      settings = {
        # Loopback only: the proxy serves this host's nix-daemon, nobody else.
        server.listen = "127.0.0.1:${toString cfg.router.port}";
        # Info logs every "nar attempt won", thousands a day.
        logging.level = lib.mkDefault "warn";
        upstreams =
          map (
            c: { inherit (c) url; } // lib.optionalAttrs (c.publicKey != null) { public_key = c.publicKey; }
          ) cfg.caches
          ++ map (u: { url = u; }) cfg.router.extraUpstreams;
      };
    };

    # Front the caches with ncro: prepend the local proxy, keep every cache in
    # marchyo.nix.caches as a direct fallback (mkBefore, not mkForce). Nix dedups
    # and routes by priority, so the localhost entry simply wins.
    nix.settings.substituters = lib.mkBefore [ "${listen}?priority=0" ];
  };
}
