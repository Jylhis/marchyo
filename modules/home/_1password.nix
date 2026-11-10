{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  defaultVaults = [
    "Private"
  ];
  format = pkgs.formats.toml { };
in
{
  options = {
    programs._1password = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable 1Password SSH agent configuration.
        '';
      };

      sshVaults = mkOption {
        type = types.listOf types.str;
        default = defaultVaults;
        description = ''
          List of vaults to include in the 1Password SSH agent configuration.
        '';
      };
    };
  };

  config = mkIf config.programs._1password.enable {
    programs.ssh.extraConfig = lib.optionalString config.programs.ssh.enable ''
      IdentityAgent ~/.1password/agent.sock
      Include ~/.ssh/1Password/config
    '';

    home.file.".config/1Password/ssh/agent.toml".source = format.generate "agent.toml" {
      ssh-keys = map (vault: { inherit vault; }) config.programs._1password.sshVaults;
    };
  };
}
