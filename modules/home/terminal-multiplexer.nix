{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    mkDefault
    types
    ;
  cfg = config.programs.tmux;
in
{
  options.programs.tmux.autoEnable = mkOption {
    type = types.bool;
    default = config.marchyo.desktop.enable or false || config.marchyo.development.enable or false;
    defaultText = "config.marchyo.desktop.enable || config.marchyo.development.enable";
    description = ''
      Automatically enable tmux when desktop or development features are enabled.
      Can be overridden by setting programs.tmux.enable explicitly.
    '';
  };

  config = mkIf cfg.autoEnable {
    programs.tmux = {
      enable = mkDefault true;

      # Use 256 colors for proper color support
      terminal = "tmux-256color";

      # Change prefix from Ctrl-b to Ctrl-a (easier to reach)
      prefix = "C-a";

      # Start window and pane numbering at 1 instead of 0
      # Makes it easier to reach with keyboard numbers
      baseIndex = 1;

      # Increase scrollback history
      historyLimit = 50000;

      # Enable mouse support
      # Allows scrolling, pane selection, and window selection with mouse
      mouse = true;

      # Enable clipboard integration via tmux-yank plugin
      # Use vi-style keybindings in copy mode
      keyMode = "vi";

      # Enable focus events for better terminal integration
      focusEvents = true;

      # Escape time for faster key sequence processing
      escapeTime = 0;

      plugins = with pkgs.tmuxPlugins; [
        # Better default settings
        {
          plugin = sensible;
          extraConfig = ''
            # sensible provides:
            # - Better default keybindings
            # - Improved scrolling behavior
            # - Automatic pane renumbering
          '';
        }

        # Clipboard integration
        {
          plugin = yank;
          extraConfig = ''
            # Copy to system clipboard
            # In copy mode (prefix+[):
            # - v: begin selection
            # - y: copy selection
            # - Enter: copy selection and cancel copy mode
            set -g @yank_selection 'clipboard'
            set -g @yank_selection_mouse 'clipboard'
          '';
        }

        # Catppuccin theme (Mocha variant)
        {
          plugin = catppuccin;
          extraConfig = ''
            # Catppuccin Mocha theme
            set -g @catppuccin_flavor 'mocha'

            # Window status format
            set -g @catppuccin_window_default_fill "number"
            set -g @catppuccin_window_default_text "#W"
            set -g @catppuccin_window_current_fill "number"
            set -g @catppuccin_window_current_text "#W"

            # Status bar modules
            set -g @catppuccin_status_modules_right "session host date_time"
            set -g @catppuccin_status_left_separator "█"
            set -g @catppuccin_status_right_separator "█"

            # Date/time format
            set -g @catppuccin_date_time_text "%Y-%m-%d %H:%M"
          '';
        }
      ];

      extraConfig = ''
        # ============================================
        # Key Bindings
        # ============================================

        # Reload tmux configuration with prefix+r
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

        # Split panes with intuitive keybindings
        # prefix+| for vertical split
        # prefix+- for horizontal split
        unbind '"'
        unbind %
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # Switch panes using Alt+arrow keys (without prefix)
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D

        # Vim-style pane navigation (with prefix)
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Resize panes with Ctrl+arrow keys (with prefix)
        bind -r C-Left resize-pane -L 5
        bind -r C-Right resize-pane -R 5
        bind -r C-Up resize-pane -U 5
        bind -r C-Down resize-pane -D 5

        # ============================================
        # Window Management
        # ============================================

        # Automatically renumber windows when one is closed
        set -g renumber-windows on

        # Enable automatic window renaming
        setw -g automatic-rename on

        # Set terminal title
        set -g set-titles on
        set -g set-titles-string "#T"

        # Monitor activity in windows
        setw -g monitor-activity on
        set -g visual-activity off

        # ============================================
        # Display Settings
        # ============================================

        # Enable visual bell instead of audible bell
        set -g visual-bell on
        set -g bell-action any

        # Display time for messages (in milliseconds)
        set -g display-time 2000

        # Update status bar every second
        set -g status-interval 1

        # Status bar position (top or bottom)
        set -g status-position bottom

        # Center the window list in status bar
        set -g status-justify left

        # ============================================
        # Copy Mode Settings
        # ============================================

        # Use vi-style keybindings in copy mode
        setw -g mode-keys vi

        # Copy mode keybindings (like vim)
        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi V send -X select-line
        bind -T copy-mode-vi C-v send -X rectangle-toggle
        bind -T copy-mode-vi y send -X copy-selection-and-cancel

        # ============================================
        # Pane Settings
        # ============================================

        # Don't allow panes to rename themselves
        set -g allow-rename off

        # Start pane numbering at 1
        setw -g pane-base-index 1

        # ============================================
        # Terminal Settings
        # ============================================

        # Enable true color support
        set -ga terminal-overrides ",*256col*:Tc"
        set -ga terminal-overrides ",xterm-*:Tc"

        # Enable RGB color support
        set -as terminal-features ",*:RGB"

        # Undercurl support
        set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
        set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'
      '';
    };
  };
}
