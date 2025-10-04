{
  programs = {
    bash = {
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
        # Default
        "checkwinsize" # Checks window size after each command.
        "complete_fullquote"
        "expand_aliases"

        # Default from home manager
        "checkjobs"
        "extglob"
        "globstar"
        "histappend"

        # Other
        "cdspell" # Tries to fix minor errors in the directory spellings
        "dirspell"
        "shift_verbose"
        "cmdhist" # Save multi-line commands as one command
      ];
      initExtra = ''
        # Enable history expansion with space
        # E.g. typing !!<space> will replace the !! with your last command
        bind Space:magic-space
      '';
    };
    readline = {
      bindings = {
        # Up and down arrows search through the history for the characters before the cursor
        "\\e[A" = "history-search-backward";
        "\\e[B" = "history-search-forward";
      };

      variables = {
        colored-completion-prefix = true; # Enable coloured highlighting of completions
        completion-ignore-case = true; # Auto-complete files with the wrong case
        revert-all-at-newline = true; # Don't save edited commands until run
        show-all-if-ambiguous = true;

      };
    };
  };
}
