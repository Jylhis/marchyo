{ lib, ... }:
let
  inherit (lib) mkOption types;

  cacheType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        example = "https://cache.nixos.org";
        description = "Binary cache URL, used both as a substituter and as an ncro upstream.";
      };
      publicKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        description = ''
          Trusted public key for this cache. `null` means the cache is
          unsigned/anonymous (no key added to `trusted-public-keys`). Non-null
          keys are added to both `nix.settings.trusted-public-keys` and, when the
          router is enabled, the ncro upstream entry's `public_key`.
        '';
      };
    };
  };
in
{
  options.marchyo.nix = {
    caches = mkOption {
      type = types.listOf cacheType;
      default = [
        {
          url = "https://jylhis.cachix.org";
          publicKey = "jylhis.cachix.org-1:SIAw5iWjXRhLAmejqPy0PGuqH6bjCHIFVF9CiHmHRpE=";
        }
        {
          url = "https://nix-community.cachix.org";
          publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
        }
        {
          url = "https://vicinae.cachix.org";
          publicKey = "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=";
        }
        {
          url = "https://devenv.cachix.org";
          publicKey = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
        }
        {
          url = "https://numtide.cachix.org";
          publicKey = "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
        }
        {
          url = "https://hyprland.cachix.org";
          publicKey = "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=";
        }
        {
          url = "https://cache.numtide.com";
          publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
        }
      ];
      description = ''
        Single source of truth for the binary caches marchyo trusts. Each entry's
        `url` populates `nix.settings.substituters` /`trusted-substituters` and its
        non-null `publicKey` populates `trusted-public-keys`. When the ncro router
        is enabled (`marchyo.nix.router.enable`), the same list is also fed to ncro
        as its upstreams, so a cache is only ever declared once.
      '';
    };

    router = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to run [ncro](https://github.com/manic-systems/ncro), the Nix
          Cache Route Optimizer, as a local `DynamicUser` systemd service that
          fronts the binary caches. When on, `http://localhost:<port>` is prepended
          to `nix.settings.substituters` (the caches in `marchyo.nix.caches` stay as
          direct fallbacks) and ncro routes each request to the fastest reachable
          upstream. NixOS only — darwin and nix-on-droid ignore this and talk to the
          caches directly.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 4200;
        description = "TCP port ncro listens on, and the port used in the prepended `http://localhost:<port>` substituter.";
      };

      netrcFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/etc/nix/netrc";
        description = ''
          Path to a netrc file ncro uses to authenticate to private upstreams
          (e.g. a sops-generated `/etc/nix/netrc`). `null` disables netrc auth.
        '';
      };

      extraUpstreams = mkOption {
        type = types.listOf types.str;
        default = [ "https://cache.nixos.org" ];
        description = ''
          Additional upstream URLs to route through ncro that are not in
          `marchyo.nix.caches`. Defaults to the upstream NixOS cache, which is
          otherwise not an explicit substituter once marchyo sets the list.
        '';
      };
    };
  };
}
