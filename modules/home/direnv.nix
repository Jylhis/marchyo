# direnv settings, applied only when the consumer opted into programs.direnv.
{ config, lib, ... }:
{
  # https://nixos.asia/en/direnv
  programs.direnv = lib.mkIf config.programs.direnv.enable {
    silent = true;
    nix-direnv.enable = lib.mkDefault true;
    config.global = {
      hide_env_diff = lib.mkDefault true;
    };
  };
}
