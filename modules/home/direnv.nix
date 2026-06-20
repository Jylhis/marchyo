# direnv settings. Opt-in: only configures when the consumer has enabled
# direnv (programs.direnv.enable), mirroring marchyo's "configure what you
# opted into" convention. Cross-platform.
{ config, lib, ... }:
{
  # https://nixos.asia/en/direnv
  programs.direnv = lib.mkIf config.programs.direnv.enable {
    silent = true;
    nix-direnv.enable = lib.mkDefault true;
    config.global = {
      # Make direnv messages less verbose
      hide_env_diff = lib.mkDefault true;
    };
  };
}
