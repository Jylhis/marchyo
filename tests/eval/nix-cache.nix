# Nix cache single-source-of-truth (marchyo.nix.caches) and the ncro router
# (marchyo.nix.router.enable, default on).
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;

  localhost = "http://localhost:4200?priority=0";
in
{
  # Default: the router is on. ncro runs, localhost is the first substituter,
  # every default cache is an ncro upstream, and cache.nixos.org rides along as
  # the default extra upstream.
  eval-nix-router-default = testNixOSCheck "nix-router-default" (
    config:
    let
      upstreamUrls = map (u: u.url) config.services.ncro.settings.upstreams;
    in
    config.services.ncro.enable
    && lib.head config.nix.settings.substituters == localhost
    && builtins.elem "https://jylhis.cachix.org" upstreamUrls
    && builtins.elem "https://cache.numtide.com" upstreamUrls
    && builtins.elem "https://cache.nixos.org" upstreamUrls
    # The direct caches stay as fallbacks alongside the proxy.
    && builtins.elem "https://jylhis.cachix.org" config.nix.settings.substituters
    && builtins.elem "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE=" config.nix.settings.trusted-public-keys
  ) (withTestUser { });

  # Opt-out: disabling the router drops ncro and the localhost substituter, but
  # the caches and keys remain as direct substituters.
  eval-nix-router-disabled =
    testNixOSCheck "nix-router-disabled"
      (
        config:
        !config.services.ncro.enable
        && !(builtins.elem localhost config.nix.settings.substituters)
        && builtins.elem "https://jylhis.cachix.org" config.nix.settings.substituters
        && builtins.elem "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE=" config.nix.settings.trusted-public-keys
      )
      (withTestUser {
        marchyo.nix.router.enable = false;
      });

  # Extensibility: a single entry appended to marchyo.nix.caches flows into both
  # the substituter list and the ncro upstreams from one declaration.
  eval-nix-cache-extend =
    testNixOSCheck "nix-cache-extend"
      (
        config:
        let
          upstreamUrls = map (u: u.url) config.services.ncro.settings.upstreams;
        in
        builtins.elem "https://example.cachix.org" config.nix.settings.substituters
        && builtins.elem "https://example.cachix.org" upstreamUrls
        && builtins.elem "example.cachix.org-1:abc=" config.nix.settings.trusted-public-keys
      )
      (withTestUser {
        marchyo.nix.caches = [
          {
            url = "https://example.cachix.org";
            publicKey = "example.cachix.org-1:abc=";
          }
        ];
      });
}
