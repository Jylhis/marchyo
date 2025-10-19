{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;

  # https://learn.omacom.io/2/the-omarchy-manual/57/shell-tools
  shellTools = with pkgs; [
    fzf # fuzzy finding of files
    ripgrep # Modern grep
    eza # Replacement for ls
    fd # Replacement for find
    sd # Replacement for sed
    choose
    procs
    dust
    duf
    gdu
    gping
    xh
    aria2
    just
    tealdeer
    dog
    lnav
    tailspin
    nix-output-monitor
  ];

  # TUI tools
  # https://learn.omacom.io/2/the-omarchy-manual/59/tuis
  tuiTools = with pkgs; [
    btop # beautiful resource manager
    fastfetch # shows system information
    bluetui # bluetooth
    sysz # systemctl tui
    lazyjournal # journald and logs
    impala # TUI for managing your Wi-Fi connection
  ];

  # Desktop GUI tools
  desktopTools = with pkgs; [
    signal-desktop # E2E messaging
    brave
    localsend # send files to other devices on the same network
    file-roller # Archive manager
    nautilus # GNOME Files (file explorer)
  ];

  # Media applications
  mediaTools = with pkgs; [
    mpv # simple fast media player
    pinta # basic image editing tool
  ];

  # Office applications
  officeTools = with pkgs; [
    libreoffice # Standard office suite
    papers # Document viewer
    xournalpp # Write to PDFs
    obsidian
  ];

  # Development tools
  devTools = with pkgs; [
    # Docker
    docker-compose
    buildah
    skopeo
    lazydocker

    # Service CLIs
    gh # Github
  ];
in
{
  config = {
    # Shell
    programs = {
      television.enable = true;
      zoxide.enable = true; # Replacement for cd
      fzf.fuzzyCompletion = true;
    };

    services = {
      tailscale.enable = true;
    };

    environment.systemPackages =
      shellTools
      ++ tuiTools
      ++ (lib.optionals cfg.desktop.enable desktopTools)
      ++ (lib.optionals cfg.media.enable mediaTools)
      ++ (lib.optionals cfg.office.enable officeTools)
      ++ (lib.optionals cfg.development.enable devTools);
  };
}
