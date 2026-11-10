{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.security = {
    fingerprint = {
      enable = lib.mkEnableOption "fingerprint authentication via fprintd (PAM integration is automatic)";
    };

    fido2 = {
      enable = lib.mkEnableOption "FIDO2/U2F hardware security key authentication via pam_u2f";
    };

    ssh = {
      enable = lib.mkEnableOption ''
        the OpenSSH server with key-only authentication: password and
        keyboard-interactive authentication are off and root cannot log in.
        Evaluation fails unless every login user that sshd admits has an
        authorized key, or sshd uses a user CA or an `AuthorizedKeysCommand`
      '';

      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "deploy" ];
        description = ''
          Normal users outside the `wheel` group that also need an authorized
          key. Members of `wheel` are always checked.
        '';
      };

      allowNoKeys = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Skip the authorized-key check, for keys that sshd gets from a place
          evaluation cannot see (for example a key file written at runtime).
        '';
      };
    };

    sudo.timestampTimeout = mkOption {
      type = types.int;
      default = 10;
      example = 0;
      description = ''
        Minutes that sudo remembers a password, written as
        `Defaults timestamp_timeout=<n>`. `0` always asks; a negative value
        never expires.
      '';
    };
  };
}
