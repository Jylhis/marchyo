{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  cfg = config.marchyo.secrets;
in
{
  # Note: sops-nix module is imported at the flake level

  options.marchyo.secrets = {
    enable = mkEnableOption "sops-nix secrets management" // {
      default = false;
      description = ''
        Enable sops-nix for managing encrypted secrets.

        Usage:
        1. Install sops and age: `nix-shell -p sops age`
        2. Generate an age key: `age-keygen -o /var/lib/sops-nix/key.txt`
        3. Create .sops.yaml in your config directory with the public key
        4. Create secrets.yaml and encrypt it: `sops secrets.yaml`
        5. Reference secrets in your configuration using `config.sops.secrets.<name>.path`

        For more information, see: https://github.com/Mic92/sops-nix
      '';
    };

    defaultSopsFile = mkOption {
      type = types.path;
      default = "/etc/nixos/secrets.yaml";
      description = ''
        Path to the default SOPS file containing encrypted secrets.
        This file should be encrypted using sops with the system's age key.
      '';
    };

    ageKeyFile = mkOption {
      type = types.path;
      default = "/var/lib/sops-nix/key.txt";
      description = ''
        Path to the age private key file used for decrypting secrets.
        Generate this with: `age-keygen -o /var/lib/sops-nix/key.txt`
      '';
    };
  };

  config = mkIf cfg.enable {
    # Configure sops-nix
    sops = {
      # Set the default SOPS file location
      inherit (cfg) defaultSopsFile;

      # Configure age key for decryption
      age = {
        keyFile = cfg.ageKeyFile;
        # Generate the key file if it doesn't exist (optional, disabled by default for security)
        # generateKey = false;
      };

      # Example secret definitions
      # Uncomment and customize these based on your needs:
      #
      # secrets = {
      #   # Example: Password for a service
      #   "example-password" = {
      #     # Optional: Set specific owner/group
      #     # owner = "root";
      #     # group = "wheel";
      #     # Optional: Set custom permissions
      #     # mode = "0440";
      #   };
      #
      #   # Example: API key
      #   "example-api-key" = {
      #     # Optional: Make available to a specific user
      #     # owner = "myuser";
      #   };
      #
      #   # Example: SSH private key
      #   "ssh-key" = {
      #     # path = "/home/myuser/.ssh/id_ed25519";
      #     # owner = "myuser";
      #     # mode = "0600";
      #   };
      # };
    };
  };
}
