{ config, lib, pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    config = {
      global = {
        # Faster cache invalidation
        strict_env = true;

        # Show loaded environment
        load_dotenv = true;
      };
    };

    # Enable bash integration if bash is enabled
    enableBashIntegration = config.programs.bash.enable;

    # Enable fish integration if fish is enabled
    enableFishIntegration = config.programs.fish.enable;

    # Enable zsh integration if zsh is enabled
    enableZshIntegration = config.programs.zsh.enable or false;
  };

  # Add direnv to PATH
  home.packages = [ pkgs.direnv ];

  # Shell integration note
  home.file.".direnvrc".text = ''
    # Source nix-direnv for improved Nix support
    source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc

    # Optional: Silence direnv output (uncomment if desired)
    # export DIRENV_LOG_FORMAT=""
  '';
}
