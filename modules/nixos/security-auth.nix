{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  # Hardware authentication factors. Enrollment stays imperative:
  #   fingerprint: run `fprintd-enroll` as the user
  #   fido2:       run `pamu2fcfg > ~/.config/Yubico/u2f_keys` with the key inserted
  config = lib.mkMerge [
    (lib.mkIf cfg.security.fingerprint.enable {
      # PAM integration is automatic in NixOS once fprintd runs; the hyprlock
      # module (modules/home/hyprlock.nix) follows services.fprintd.enable via
      # osConfig, so the lock screen picks this up without further wiring.
      services.fprintd.enable = true;
    })

    (lib.mkIf cfg.security.fido2.enable {
      security.pam.u2f = {
        enable = true;
        # Prompt "Please touch the device." so authentication doesn't appear
        # to hang while the key waits for a touch.
        settings.cue = true;
      };

      # pamu2fcfg ships in pam_u2f, which the nixpkgs pam module already adds
      # to systemPackages when security.pam.u2f.enable is set; libfido2
      # provides the fido2-token/fido2-cred CLI for key management.
      environment.systemPackages = [ pkgs.libfido2 ];
    })
  ];
}
