{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.security = {
    firewall = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether the firewall is on by default. `networking.firewall.enable`
          defaults to this value (via `mkDefault`), so setting it `false` is a
          real off-switch — NixOS itself would otherwise leave the firewall
          enabled. Hosts can still override `networking.firewall.enable`
          directly in either direction. Service modules (avahi, LocalSend,
          tailscale) keep registering their ports/interfaces regardless; those
          only take effect when the firewall ends up enabled.
        '';
      };
    };

    fingerprint = {
      enable = lib.mkEnableOption "fingerprint authentication via fprintd (PAM integration is automatic)";
    };

    fido2 = {
      enable = lib.mkEnableOption "FIDO2/U2F hardware security key authentication via pam_u2f";
    };
  };
}
