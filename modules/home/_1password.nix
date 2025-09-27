{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  # Default values for the module
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
    # Ensure 1Password is installed before configuring SSH agent
    programs.ssh.extraConfig = lib.optionalString config.programs.ssh.enable ''
      IdentityAgent ~/.1password/agent.sock
      Include ~/.ssh/1Password/config
    '';

    # Configure the 1Password SSH agent TOML file
    home.file.".config/1Password/ssh/agent.toml".source = format.generate "agent.toml" {
      ssh-keys = map (vault: { inherit vault; }) config.programs._1password.sshVaults;
    };
  };
}
