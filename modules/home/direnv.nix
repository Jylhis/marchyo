{ lib, pkgs, ... }:

{
  programs.direnv = {
    enable = lib.mkDefault true;
    nix-direnv.enable = lib.mkDefault true;

    config = {
      global = {
        # Faster cache invalidation
        strict_env = true;

        # Show loaded environment
        load_dotenv = true;
      };
    };

    # Shell integrations are automatically enabled by Home Manager
    # based on which shells are enabled (bash, fish, zsh)
  };

  # Custom direnvrc for nix-direnv
  home.file.".direnvrc".text = ''
    # Source nix-direnv for improved Nix support
    source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc

    # Optional: Silence direnv output (uncomment if desired)
    # export DIRENV_LOG_FORMAT=""
  '';
}
