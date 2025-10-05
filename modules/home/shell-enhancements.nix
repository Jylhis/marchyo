_:

{
  programs.bash = {
    # Additional bash aliases not in generic/shell.nix
    shellAliases = {
      # System management shortcuts (using Marchyo scripts)
      update = "cd /etc/nixos && sudo ./scripts/update.sh";
      rollback = "cd /etc/nixos && sudo ./scripts/rollback.sh";
      health = "cd /etc/nixos && sudo ./scripts/health-check.sh";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos";
      rebuild-test = "sudo nixos-rebuild test --flake /etc/nixos";

      # Nix-specific aliases
      nix-shell-pure = "nix-shell --pure";
      nix-search = "nix search nixpkgs";
      nix-info = "nix-shell -p nix-info --run nix-info";
      nix-clean = "sudo nix-collect-garbage -d";
      nix-clean-old = "sudo nix-collect-garbage --delete-older-than 30d";
      nix-optimise = "nix-store --optimise";
      nix-why = "nix-store --query --roots";
      nix-tree-size = "nix-store -q --tree --size";

      # Enhanced file operations
      cat = "bat";
      find = "fd";
      grep = "rg";
      du = "dust";
      ps = "procs";
      top = "btop";

      # Git shortcuts (extending generic/shell.nix)
      gs = "git status";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit";
      gp = "git push";
      gpl = "git pull";
      gd = "git diff";
      gds = "git diff --staged";
      gl = "git log --oneline --graph --decorate";
      gla = "git log --oneline --graph --decorate --all";
      gco = "git checkout";
      gcb = "git checkout -b";
      gb = "git branch";
      gba = "git branch -a";
      gbd = "git branch -d";
      gm = "git merge";
      gr = "git reset";
      grh = "git reset --hard";
      grs = "git reset --soft";
      gst = "git stash";
      gstp = "git stash pop";
      gstl = "git stash list";

      # Docker shortcuts (when development.enable)
      d = "docker";
      dc = "docker-compose";
      dps = "docker ps";
      dpsa = "docker ps -a";
      di = "docker images";
      dex = "docker exec -it";
      dlogs = "docker logs -f";
      dstop = "docker stop";
      drm = "docker rm";
      drmi = "docker rmi";
      dprune = "docker system prune -a";

      # Network utilities
      ports = "netstat -tulanp";
      listening = "lsof -i -P -n | grep LISTEN";
      myip = "curl -s ifconfig.me";
      ping = "ping -c 5";

      # Safety aliases (ask before dangerous operations)
      rm = "rm -i";
      mv = "mv -i";
      cp = "cp -i";

      # Quick navigation
      cdnix = "cd /etc/nixos";
      cdhome = "cd ~";
      cddev = "cd ~/Developer";

      # Systemd shortcuts
      sc = "systemctl";
      scs = "systemctl status";
      scr = "sudo systemctl restart";
      sce = "sudo systemctl enable";
      scd = "sudo systemctl disable";
      scl = "journalctl -xe";
      sclf = "journalctl -f";
      scu = "systemctl --user";
      scus = "systemctl --user status";

      # Disk usage
      df = "df -h";
      free = "free -h";

      # History
      h = "history";
      hg = "history | grep";

      # Quick edits
      v = "nvim";
      vi = "nvim";
      vim = "nvim";

      # Misc utilities
      weather = "curl wttr.in";
      cheat = "curl cheat.sh/";
      j = "zoxide"; # Jump to directory
    };

    # Additional bash initialization
    initExtra = ''
      # Function: Extract various archive formats
      extract() {
        if [ -f "$1" ]; then
          case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
          esac
        else
          echo "'$1' is not a valid file"
        fi
      }

      # Function: Create directory and cd into it
      mkcd() {
        mkdir -p "$1" && cd "$1"
      }

      # Function: Show colors in terminal
      colors() {
        for i in {0..255}; do
          printf "\x1b[38;5;''${i}mcolour''${i}\x1b[0m\n"
        done
      }

      # Function: Quick backup of a file
      backup() {
        if [ -f "$1" ]; then
          cp "$1" "$1.backup-$(date +%Y%m%d-%H%M%S)"
          echo "Backed up $1 to $1.backup-$(date +%Y%m%d-%H%M%S)"
        else
          echo "'$1' is not a file"
        fi
      }

      # Function: Show disk usage of current directory
      diskusage() {
        du -sh * | sort -h
      }

      # Function: Show largest files in current directory
      largest() {
        find . -type f -exec du -h {} + | sort -rh | head -n ''${1:-10}
      }

      # Function: Git commit with message
      gitc() {
        git add -A && git commit -m "$*"
      }

      # Function: Git push to origin current branch
      gitpush() {
        BRANCH=$(git branch --show-current)
        git push origin "$BRANCH"
      }

      # Function: Quickly search for a process
      psg() {
        ps aux | grep -v grep | grep -i -e VSZ -e "$@"
      }

      # Function: Kill process by name
      killnamed() {
        pkill -f "$1"
      }

      # Function: Show PATH in readable format
      path() {
        echo "$PATH" | tr ':' '\n' | nl
      }

      # Enhanced cd - use zoxide if available
      if command -v zoxide &> /dev/null; then
        eval "$(zoxide init bash)"
        alias cd='z'
      fi

      # Enhanced history search with fzf if available
      if command -v fzf &> /dev/null; then
        # Ctrl+R for history search with fzf
        bind '"\C-r": "\C-x1\e^\er"'
        bind -x '"\C-x1": __fzf_history';

        __fzf_history() {
          READLINE_LINE=$(HISTTIMEFORMAT= history | fzf --tac --tiebreak=index | sed 's/ *[0-9]* *//')
          READLINE_POINT=''${#READLINE_LINE}
        }

        # Ctrl+T for file search with fzf
        bind -x '"\C-t": __fzf_select'
        __fzf_select() {
          READLINE_LINE=$(find . -type f 2>/dev/null | fzf)
          READLINE_POINT=''${#READLINE_LINE}
        }
      fi

      # Colored man pages
      export MANPAGER="sh -c 'col -bx | bat -l man -p'"

      # Set default editor
      export EDITOR="nvim"
      export VISUAL="nvim"

      # Colored GCC warnings and errors
      export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

      # Better less options
      export LESS='-R -F -X -i -M -w -z-4'
      export LESSHISTFILE=-

      # Enable colored output for ls (eza), grep, etc.
      export CLICOLOR=1
      export GREP_COLOR='1;33'
    '';

    # Bash history settings
    historyFileSize = 100000;
    historySize = 10000;
  };

  # Fish shell aliases (if fish is enabled)
  programs.fish = {
    shellAliases = {
      # Mirror bash aliases for fish
      # Fish uses different syntax for some things, but aliases work the same
      update = "cd /etc/nixos && sudo ./scripts/update.sh";
      rollback = "cd /etc/nixos && sudo ./scripts/rollback.sh";
      health = "cd /etc/nixos && sudo ./scripts/health-check.sh";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos";

      cat = "bat";
      find = "fd";
      grep = "rg";
      top = "btop";

      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate";

      # System
      sc = "systemctl";
      scu = "systemctl --user";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    # Fish-specific configuration
    interactiveShellInit = ''
      # Fish greeting
      set fish_greeting ""

      # Enable vi mode
      fish_vi_key_bindings

      # Zoxide integration
      if command -v zoxide &> /dev/null
        zoxide init fish | source
        alias cd='z'
      end

      # Better defaults
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

      # Fish-specific functions
      function mkcd
        mkdir -p $argv[1]; and cd $argv[1]
      end

      function backup
        cp $argv[1] $argv[1].backup-(date +%Y%m%d-%H%M%S)
      end

      function extract
        switch $argv[1]
          case '*.tar.bz2'
            tar xjf $argv[1]
          case '*.tar.gz'
            tar xzf $argv[1]
          case '*.tar.xz'
            tar xJf $argv[1]
          case '*.zip'
            unzip $argv[1]
          case '*'
            echo "Unknown archive format"
        end
      end
    '';
  };

  # Zoxide for smart directory jumping
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # Bat (better cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      pager = "less -FR";
      style = "numbers,changes,header";
    };
  };

  # Eza (better ls) - already enabled in generic, just add config
  home.file.".config/eza/theme.yml".text = ''
    # Eza color theme
    # Uses same colors as ls with enhanced icons
  '';

  # FZF (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    defaultCommand = "fd --type f --hidden --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--border"
      "--layout=reverse"
      "--info=inline"
      "--preview 'bat --style=numbers --color=always {}'"
      "--preview-window 'right:60%:wrap'"
      "--bind 'ctrl-/:toggle-preview'"
      "--color=dark"
      "--color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f"
      "--color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7"
    ];

    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --level=2 --color=always {}'"
    ];

    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    fileWidgetOptions = [
      "--preview 'bat --style=numbers --color=always {}'"
    ];
  };

  # Starship prompt (configured via generic/shell.nix, just add custom config)
  programs.starship.settings = {
    add_newline = true;
    scan_timeout = 10;

    character = {
      success_symbol = "[➜](bold green)";
      error_symbol = "[➜](bold red)";
    };

    directory = {
      truncation_length = 3;
      truncate_to_repo = true;
    };

    git_branch = {
      symbol = " ";
      style = "bold purple";
    };

    git_status = {
      ahead = "⇡\${count}";
      behind = "⇣\${count}";
      diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
      conflicted = "🏳";
      untracked = "🤷";
      stashed = "📦";
      modified = "📝";
      staged = "✓";
      renamed = "👅";
      deleted = "🗑";
    };

    nix_shell = {
      symbol = " ";
      format = "via [$symbol$state]($style) ";
    };

    package = {
      disabled = true;
    };
  };
}
