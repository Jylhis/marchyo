# marchyo's binary caches (modules/nixos/caches.json) and the ncro router
# (services.ncro.enable, on by default through marchyo), which routes every
# substituter.
{ lib, ... }:
let
  localhost = "http://localhost:4200?priority=0";
in
{
  refs = {
    # Default: the router is on. ncro runs, localhost is the first substituter,
    # every default cache is an ncro upstream, and cache.nixos.org rides along as
    # the default extra upstream.
    headless.eval-nix-router-default =
      config:
      let
        upstreamUrls = map (u: u.url) config.services.ncro.settings.upstreams;
      in
      config.services.ncro.enable
      && lib.head config.nix.settings.substituters == localhost
      && builtins.elem "https://jylhis.cachix.org" upstreamUrls
      && builtins.elem "https://nix-community.cachix.org" upstreamUrls
      # Caches for inputs marchyo no longer has stay out.
      && !(builtins.any (u: lib.hasInfix "numtide" u || lib.hasInfix "hyprland" u) (
        upstreamUrls ++ config.nix.settings.substituters
      ))
      && builtins.elem "https://cache.nixos.org" upstreamUrls
      # ncro itself is not its own upstream.
      && !(builtins.any (lib.hasPrefix "http://localhost") upstreamUrls)
      # Upstreams carry the trusted key named after their host.
      && builtins.elem {
        url = "https://jylhis.cachix.org";
        public_key = "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE=";
      } config.services.ncro.settings.upstreams
      # The direct caches stay as fallbacks alongside the proxy.
      && builtins.elem "https://jylhis.cachix.org" config.nix.settings.substituters
      && builtins.elem "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE=" config.nix.settings.trusted-public-keys;

    # Opt-out (services.ncro.enable = false): disabling the router drops ncro
    # and the localhost substituter, but the caches and keys remain as direct
    # substituters.
    headless-tweaks.eval-nix-router-disabled =
      config:
      !config.services.ncro.enable
      && !(builtins.elem localhost config.nix.settings.substituters)
      && builtins.elem "https://jylhis.cachix.org" config.nix.settings.substituters
      && builtins.elem "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE=" config.nix.settings.trusted-public-keys;

    # Extensibility: a substituter the host adds merges with marchyo's list and
    # becomes an ncro upstream, with its key.
    headless-tweaks-2.eval-nix-cache-extend =
      config:
      let
        upstreamUrls = map (u: u.url) config.services.ncro.settings.upstreams;
      in
      builtins.elem "https://example.cachix.org" config.nix.settings.substituters
      && builtins.elem "https://jylhis.cachix.org" config.nix.settings.substituters
      && builtins.elem "https://example.cachix.org" upstreamUrls
      && builtins.elem {
        url = "https://example.cachix.org";
        public_key = "example.cachix.org-1:abc=";
      } config.services.ncro.settings.upstreams
      && builtins.elem "example.cachix.org-1:abc=" config.nix.settings.trusted-public-keys;

    # Trusted users default to @wheel plus the enabled marchyo users (NixOS adds root).
    headless.eval-nix-trusted-users-default =
      config:
      config.nix.settings.trusted-users == [
        "root"
        "@wheel"
        "testuser"
      ];

    # marchyo.nix.trustedUsers overrides the list (headless-tweaks-3).
    headless-tweaks-3.eval-nix-trusted-users-override =
      config:
      config.nix.settings.trusted-users == [
        "root"
        "@wheel"
      ];

    # marchyo.nix.extraCaches is appended to the built-in list and, through the
    # merged substituters, becomes an ncro upstream with its key
    # (headless-tweaks-3); the built-in caches stay.
    headless-tweaks-3.eval-nix-extra-caches =
      config:
      let
        upstreamUrls = map (u: u.url) config.services.ncro.settings.upstreams;
      in
      builtins.elem "https://extra.example.org" config.nix.settings.substituters
      && builtins.elem "https://extra.example.org" config.nix.settings.trusted-substituters
      && builtins.elem "https://jylhis.cachix.org" config.nix.settings.substituters
      && builtins.elem "extra.example.org-1:def=" config.nix.settings.trusted-public-keys
      && builtins.elem "https://extra.example.org" upstreamUrls
      && builtins.elem {
        url = "https://extra.example.org";
        public_key = "extra.example.org-1:def=";
      } config.services.ncro.settings.upstreams;

    # No extra caches by default.
    headless.eval-nix-extra-caches-default =
      config:
      config.marchyo.nix.extraCaches == [ ]
      && !(builtins.elem "https://extra.example.org" config.nix.settings.substituters);
  };

  refConfig = {
    headless-tweaks-3.marchyo.nix = {
      trustedUsers = [ "@wheel" ];
      extraCaches = [
        {
          url = "https://extra.example.org";
          publicKey = "extra.example.org-1:def=";
        }
      ];
    };
    headless-tweaks.services.ncro.enable = false;
    headless-tweaks-2.nix.settings = {
      substituters = [ "https://example.cachix.org" ];
      trusted-public-keys = [ "example.cachix.org-1:abc=" ];
    };
  };
}
