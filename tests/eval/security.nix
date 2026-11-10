{ lib, ... }:
{
  refs = {
    # Fingerprint + FIDO2 enabled: fprintd runs, pam_u2f is wired with the touch
    # cue, and the libfido2 key-management CLI is installed system-wide
    # (pamu2fcfg comes with pam_u2f via the nixpkgs pam module itself).
    headless-tweaks.eval-security-auth-enabled =
      cfg:
      cfg.services.fprintd.enable
      && cfg.security.pam.u2f.enable
      && cfg.security.pam.u2f.settings.cue
      && builtins.any (p: lib.getName p == "libfido2") cfg.environment.systemPackages;

    # Default state: the firewall is on.
    headless.eval-security-firewall-default = cfg: cfg.networking.firewall.enable;

    # The host turns the firewall off with the upstream option.
    headless-tweaks-3.eval-security-firewall-host-override = cfg: !cfg.networking.firewall.enable;
  };

  refConfig = {
    headless-tweaks.marchyo.security = {
      fingerprint.enable = true;
      fido2.enable = true;
    };
    headless-tweaks-3.networking.firewall.enable = false;
  };
}
