{
  programs = {
    bash = {
      enable = true;
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

        # Copy-on-write (reflink) where the filesystem supports it; `=auto`
        # falls back to a full copy elsewhere.
        cp = "cp --reflink=auto";
      };
      enableCompletion = true;
      enableVteIntegration = true;
      historyControl = [
        "ignoreboth"
        "erasedups"
      ];
      historyIgnore = [
        "$"
        "[ ]*"
        "exit"
        "ls"
        "bg"
        "fg"
        "history"
        "clear"
        "cd"
        "rm"
        "cat"
      ];
      shellOptions = [
        "checkwinsize"
        "complete_fullquote"
        "expand_aliases"
        "checkjobs"
        "extglob"
        "globstar"
        "histappend"
        "cdspell" # Fix minor errors in directory spellings
        "dirspell"
        "shift_verbose"
        "cmdhist" # Save multi-line commands as one history entry
      ];
      initExtra = ''
        # magic-space: expand history inline (e.g. !!<space> becomes your last command).
        bind Space:magic-space
      '';
    };
    readline = {
      bindings = {
        # Up/down arrows search history for the characters before the cursor.
        "\\e[A" = "history-search-backward";
        "\\e[B" = "history-search-forward";
      };

      variables = {
        colored-completion-prefix = true;
        completion-ignore-case = true;
        revert-all-at-newline = true; # Don't save edited commands until run
        show-all-if-ambiguous = true;
      };
    };
  };
}
