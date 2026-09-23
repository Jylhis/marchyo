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
    gum # shell-script UI toolkit (prompts, spinners, styled output)
    imagemagick # image conversion/resize/manipulation CLI
    inxi # full-featured system information tool (hardware/driver report)
  ];

  tuiTools = with pkgs; [
    btop # beautiful resource manager (replaces gnome-system-monitor)
    fastfetch # shows system information
    bluetui # bluetooth
    sysz # systemctl tui
    lazyjournal # journald and logs
    dua # interactive disk-usage analyzer TUI
    wiremix # PipeWire mixer TUI
    cliamp # retro terminal music player (Winamp-style)
  ];

  desktopTools = with pkgs; [
    signal-desktop # E2E messaging
    loupe # Modern GNOME image viewer
    gnome-disk-utility # Disk management
    sushi # Quick file previews in Nautilus
    dconf-editor # For debugging dconf/GTK settings
    quickshell # QtQuick toolkit for building custom Wayland shells/bars
  ];

  mediaTools = with pkgs; [ ];

  officeTools = with pkgs; [
    # papers # Document viewer. Slow to compile. Find lighter alternative?
    obsidian
  ];

  # Development tools
  devTools = with pkgs; [
    docker-compose
    buildah
    skopeo
    lazydocker

    gh # Github
  ];
in
{
  config = {
    programs = {
      television.enable = lib.mkDefault true;
      fzf.fuzzyCompletion = lib.mkDefault true;
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
