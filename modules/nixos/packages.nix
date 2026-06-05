{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;

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
    ouch # archive compression/extraction (replaces file-roller)
  ];

  tuiTools = with pkgs; [
    btop # beautiful resource manager (replaces gnome-system-monitor)
    fastfetch # shows system information
    bluetui # bluetooth
    sysz # systemctl tui
    lazyjournal # journald and logs
    impala # TUI for managing your Wi-Fi connection
    # qalc (calculator REPL, replaces gnome-calculator) installs via the
    # programs.qalculate Home-Manager module (modules/home/qalculate.nix).
  ];

  # Desktop GUI tools
  desktopTools = with pkgs; [
    signal-desktop # E2E messaging
    localsend # send files to other devices on the same network
    loupe # Modern GNOME image viewer
    gnome-disk-utility # Disk management
    sushi # Quick file previews in Nautilus
    dconf-editor # For debugging dconf/GTK settings
  ];

  # Media applications (browser/editor/video/audio/fileManager managed by defaults.nix)
  mediaTools = with pkgs; [ ];

  # Office applications
  officeTools = with pkgs; [
    # libreoffice # Standard office suite
    papers # Document viewer
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
