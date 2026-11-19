{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  cacheType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        example = "https://my-cache.example.com";
        description = "Binary cache URL.";
      };
      publicKey = mkOption {
        type = types.str;
        example = "my-cache.example.com-1:AAAA...=";
        description = ''
          Public key that signs the cache's store paths. Name the key after
          the cache's host (`<host>-<n>:...`) so the ncro cache router pairs it
          with this upstream.
        '';
      };
    };
  };
in
{
  options.marchyo.nix = {
    trustedUsers = mkOption {
      type = types.listOf types.str;
      default = [
        "@wheel"
      ]
      ++ lib.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
      defaultText = lib.literalMD "`@wheel` and every enabled `marchyo.users` entry";
      example = [ "@wheel" ];
      description = ''
        Value of `nix.settings.trusted-users`. A trusted user can import
        store paths that carry no valid signature and override restricted
        Nix settings, so it can place arbitrary content in the store and is
        effectively root. Narrow the list on a host where the Marchyo users
        should not hold that power.
      '';
    };

    extraCaches = mkOption {
      type = types.listOf cacheType;
      default = [ ];
      example = [
        {
          url = "https://my-cache.example.com";
          publicKey = "my-cache.example.com-1:AAAA...=";
        }
      ];
      description = ''
        Binary caches added to marchyo's built-in list (`modules/nixos/caches.json`).
        Each `url` joins `nix.settings.substituters` and
        `trusted-substituters`, and each `publicKey` joins
        `nix.settings.trusted-public-keys`. The ncro cache router, when on,
        routes the merged substituter list, so an extra cache becomes an
        upstream with its key.
      '';
    };
  };
}
