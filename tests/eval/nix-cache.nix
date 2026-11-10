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
  };

  refConfig = {
    headless-tweaks.services.ncro.enable = false;
    headless-tweaks-2.nix.settings = {
      substituters = [ "https://example.cachix.org" ];
      trusted-public-keys = [ "example.cachix.org-1:abc=" ];
    };
  };
}
