{ pkgs, ... }:
let
  # https://learn.omacom.io/2/the-omarchy-manual/57/shell-tools
  shellTools = with pkgs; [
    fzf # fuzzy finding of files
    ripgrep # Modern grep
    eza # Replacement for ls
    fd # Replacement for find
  ];

  # TUI tools
  # https://learn.omacom.io/2/the-omarchy-manual/59/tuis
  tuiTools = with pkgs; [
    lazydocker # made in the same spirit like Lazygit,
    btop # beautiful resource manager
    impala # TUI for managing your Wi-Fi connection
    fastfetch # shows system information
    bluetui # bluetooth
    lazyssh
    sysz # systemctl tui
    lazyjournal # journald and logs
  ];

  # GUI tools
  # https://learn.omacom.io/2/the-omarchy-manual/60/guis
  guiTools = with pkgs; [
    pinta # basic image editing tool
    localsend # send files to other devices on the same network
    libreoffice # Standard office suite
    signal-desktop # E2E messaging
    mpv # simple fast media player
  ];

  # Commercial GUIs
  # https://learn.omacom.io/2/the-omarchy-manual/61/commercial-guis
  commercialGUITools = with pkgs; [
    spotify
  ];

  # Development tools
  devTools = with pkgs; [
    # Docker
    docker-compose
    buildah
    skopeo

    # Service CLIs
    gh # Github
  ];

  basicTools = with pkgs; [
    papers # Document viewer
    xournalpp # Write to PDFs
    # TODO: hyprmon
  ];

  # Customization
  # TODO: wallpapaer: https://github.com/dharmx/walls
in
{

  # https://github.com/basecamp/omarchy/blob/master/default/mako/core.ini

  # TODO: Disk config
  # btrfs
  # Installer
  config = {

    # Shell
    programs = {
      zoxide.enable = true; # Replacement for cd
      # TODO compress and decompress commands
      starship = {
        enable = true; # Prompt
        settings = {
          add_newline = true;
          command_timeout = 200;
          format = "[$directory$git_branch$git_status]($style)$character";

          # error_symbol = "[✗](bold cyan)";
          # success_symbol = "[❯](bold cyan)";
          character = { };

          directory = {
            truncation_length = 2;
            truncation_symbol = "…/";
            repo_root_style = "bold cyan";
            repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
          };

          git_branch = {
            format = "[$branch]($style) ";
            style = "italic cyan";
          };

          git_status = {
            format = "[$all_status]($style)";
            style = "cyan";
            ahead = "⇡\${count} ";
            diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
            behind = "⇣\${count} ";
            conflicted = " ";
            up_to_date = " ";
            untracked = "? ";
            modified = " ";
            stashed = "";
            staged = "";
            renamed = "";
            deleted = "";
          };
        };
      };
    };

    # TUI
    programs = {
      lazygit.enable = true; # delightful alternative to something like the GitHub Desktop application,
    };

    services = {
      tailscale.enable = true;
    };

    # DEVELOPMENT tools
    # https://learn.omacom.io/2/the-omarchy-manual/62/development-tools
    # TODO: Switch to kitty
    # https://sw.kovidgoyal.net/kitty/faq/#i-get-errors-about-the-terminal-being-unknown-or-opening-the-terminal-failing-or-functional-keys-like-arrow-keys-don-t-work

    # Web Apps
    # https://learn.omacom.io/2/the-omarchy-manual/63/web-apps

    # Policies for chromium based browsers
    # programs.chormium = {
    #   enable = true;
    #   # TODO: https://github.com/basecamp/omarchy/blob/master/config/chromium-flags.conf
    # };

    environment.systemPackages =
      shellTools ++ tuiTools ++ guiTools ++ commercialGUITools ++ devTools ++ basicTools;

    # Enable wayland support on chrome
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # TODO:
    # https://github.com/basecamp/omarchy/blob/master/config/xournalpp/settings.xml
    # https://github.com/basecamp/omarchy/tree/master/config/waybar
    # https://github.com/basecamp/omarchy/blob/master/config/kitty/kitty.conf
    # hypr https://github.com/basecamp/omarchy/tree/master/config/hypr
    # ghostty: https://github.com/basecamp/omarchy/tree/master/config/ghostty
    # https://github.com/basecamp/omarchy/blob/master/config/fastfetch/config.jsonc
  };

}
