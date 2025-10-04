_: {
  programs = {
    # Only options that work in both NixOS and Home Manager
    bash = {
      enable = true;
      # shellAliases works in both contexts
      shellAliases = {
        ls = "eza -lh --group-directories-first --icons=auto";
        lsa = "ls -a";
        lt = "eza --tree --level=2 --long --icons --git";
        lta = "lt -a";
        ff = "fzf --preview 'bat --style=numbers --color=always {}'";

        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";

        g = "git";
        gcm = "git commit -m";
        gcam = "git commit -a -m";
        gcad = "git commit -a --amend";
      };
    };

    fish = {
      enable = true;
    };

    starship.enable = true;
  };
}
