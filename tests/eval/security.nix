{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  # Fingerprint + FIDO2 enabled: fprintd runs, pam_u2f is wired with the touch
  # cue, and the libfido2 key-management CLI is installed system-wide
  # (pamu2fcfg comes with pam_u2f via the nixpkgs pam module itself).
  eval-security-auth-enabled =
    testNixOSCheck "security-auth-enabled"
      (
        cfg:
        cfg.services.fprintd.enable
        && cfg.security.pam.u2f.enable
        && cfg.security.pam.u2f.settings.cue
        && builtins.any (p: lib.getName p == "libfido2") cfg.environment.systemPackages
      )
      (withTestUser {
        marchyo.security = {
          fingerprint.enable = true;
          fido2.enable = true;
        };
      });

  # Default state: the firewall is on.
  eval-security-firewall-default = testNixOSCheck "security-firewall-default" (
    cfg: cfg.networking.firewall.enable
  ) (withTestUser { });

  # The host turns the firewall off with the upstream option.
  eval-security-firewall-host-override =
    testNixOSCheck "security-firewall-host-override" (cfg: !cfg.networking.firewall.enable)
      (withTestUser {
        networking.firewall.enable = false;
      });
}
