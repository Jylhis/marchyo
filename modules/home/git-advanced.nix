# Advanced Git configuration with aliases, delta, and lazygit
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
in
{
  config = mkIf (config.marchyo.development.enable or false) {
    programs.git = {
      # Git aliases for common operations
      aliases = {
        # Short status with branch information
        st = "status -sb";

        # Checkout shorthand
        co = "checkout";

        # Branch shorthand
        br = "branch";

        # Commit shorthand
        ci = "commit";

        # Unstage files (opposite of git add)
        unstage = "reset HEAD --";

        # Show the last commit
        last = "log -1 HEAD";

        # Pretty graph log with colors
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";

        # Amend the last commit without editing the message
        amend = "commit --amend --no-edit";

        # Create a fixup commit (useful for interactive rebase)
        fix = "commit --fixup";

        # Undo the last commit but keep changes staged
        undo = "reset --soft HEAD^";
      };

      # Enable delta for enhanced diffs
      delta = {
        enable = mkDefault true;
        options = {
          # Use Catppuccin theme for beautiful diffs
          features = "catppuccin-mocha";

          # Display diffs side-by-side when terminal is wide enough
          side-by-side = true;

          # Show line numbers in diffs
          line-numbers = true;

          # Enable syntax highlighting
          syntax-theme = "Catppuccin-mocha";
        };
      };

      # Additional git configuration (avoiding conflicts with git.nix)
      extraConfig = {
        # Automatically setup remote tracking when pushing new branches
        push = {
          autoSetupRemote = mkDefault true;
        };

        # Automatically prune deleted remote branches when fetching
        fetch = {
          prune = mkDefault true;
        };

        # Automatically stash uncommitted changes before rebase
        rebase = {
          autoStash = mkDefault true;
        };
      };
    };

    # Configure lazygit settings (lazygit.enable is set in git.nix)
    programs.lazygit.settings = {
      # Use Catppuccin theme for consistent styling
      gui = {
        theme = {
          activeBorderColor = [
            "#a6e3a1"
            "bold"
          ];
          inactiveBorderColor = [ "#313244" ];
          selectedLineBgColor = [ "#313244" ];
          selectedRangeBgColor = [ "#313244" ];
        };
      };

      # Respect git configuration
      git = {
        paging = {
          # Use delta for diffs in lazygit
          colorArg = "always";
          pager = "${lib.getExe pkgs.delta} --dark --paging=never";
        };
      };
    };
  };
}
