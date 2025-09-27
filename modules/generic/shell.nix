_: {
  programs = {
    bash = {
      # enable = true; # TODO: Only for home-manager

      # https://github.com/basecamp/omarchy/blob/master/default/bash/aliases
      shellAliases = {
        ls = "eza -lh --group-directories-first --icons=auto";
        lsa = "ls -a";
        lt = "eza --tree --level=2 --long --icons --git";
        lta = "lt -a";
        ff = "fzf --preview 'bat --style=numbers --color=always {}'";
        # cd = "zd"; # FIXME

        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";

        g = "git";
        gcm = "git commit -m";
        gcam = "git commit -a -m";
        gcad = "git commit -a --amend";
      };

      # set
      #     shopt -s histappend
      # HISTCONTROL=ignoreboth
      # HISTSIZE=32768
      # HISTFILESIZE="${HISTSIZE}"
      # Technicolor dreams
      # force_color_prompt=yes
      # color_prompt=yes

      # # Simple prompt with path in the window/pane title and caret for typing line
      # PS1=$'\uf0a9 '
      # PS1="\[\e]0;\w\a\]$PS1"

      # https://github.com/basecamp/omarchy/blob/master/default/bash/inputrc

      # TODO: Make sure all system tool autocompletes work https://github.com/basecamp/omarchy/blob/master/default/bash/init

      # TODO: Functions: https://github.com/basecamp/omarchy/blob/master/default/bash/functions

      # Editor used by CLI
      # export SUDO_EDITOR="$EDITOR"
      # export BAT_THEME=ansi
    };
    fish = {
      enable = true;
    };

    starship.enable = true;
  };
}
