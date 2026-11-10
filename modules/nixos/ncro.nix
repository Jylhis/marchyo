# ncro, the Nix Cache Route Optimizer, fronting the binary caches. On by
# default (services.ncro.enable at mkDefault); everything below follows
# services.ncro.enable.
{ config, lib, ... }:
let
  cfg = config.services.ncro;
  listen = "http://localhost:${toString cfg.port}";

  # Every substituter except ncro itself becomes an ncro upstream, so a cache
  # is declared once, in nix.settings.substituters. Query strings
  # (`?priority=`) and trailing slashes are Nix-side details ncro does not need.
  upstreamUrls = lib.unique (
    map (s: lib.removeSuffix "/" (builtins.head (lib.splitString "?" s))) (
      lib.filter (s: !lib.hasPrefix listen s) config.nix.settings.substituters
    )
  );

  # A cache's key is named after its host by convention
  # (`cache.nixos.org-1:...`), so match trusted keys to upstreams that way.
  urlHost = url: builtins.head (builtins.match "[a-z]+://([^/:]+).*" url);
  keysFor =
    url:
    lib.filter (
      key:
      let
        m = builtins.match "([^:]+)-[0-9]+:.*" key;
      in
      m != null && builtins.head m == urlHost url
    ) config.nix.settings.trusted-public-keys;
in
{
  config = lib.mkMerge [
    { services.ncro.enable = lib.mkDefault true; }

    (lib.mkIf cfg.enable {
      services.ncro = {
        port = lib.mkDefault 4200;
        # The keys come from nix.settings.trusted-public-keys already; feeding
        # them back would make the upstream list depend on itself.
        addUpstreamPublicKeys = false;
        settings = {
          # Info logs every "nar attempt won", thousands a day.
          logging.level = lib.mkDefault "warn";
          upstreams = map (
            url:
            let
              keys = keysFor url;
            in
            {
              inherit url;
            }
            // lib.optionalAttrs (builtins.length keys == 1) { public_key = builtins.head keys; }
            // lib.optionalAttrs (builtins.length keys > 1) { public_keys = keys; }
          ) upstreamUrls;
        };
      };

      # Front the caches with ncro: prepend the local proxy, keep every other
      # substituter as a direct fallback (mkBefore, not mkForce). Nix routes by
      # priority, so the localhost entry wins.
      nix.settings.substituters = lib.mkBefore [ "${listen}?priority=0" ];
    })
  ];
}
