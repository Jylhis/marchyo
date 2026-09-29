{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;

  shellTools = with pkgs; [
    fzf
    ripgrep
    eza
    fd
    sd
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
    ouch
    gum
    imagemagick
    chafa # backs `marchyo transcode ascii`
    inxi
  ];

  tuiTools = with pkgs; [
    btop
    fastfetch
    bluetui
    sysz
    lazyjournal
    dua
    wiremix
    cliamp
  ];

  desktopTools = with pkgs; [
    signal-desktop
    loupe
    gnome-disk-utility
    sushi
    dconf-editor
    quickshell
  ];

  mediaTools = with pkgs; [ ];

  officeTools = with pkgs; [
    obsidian
    xournalpp
  ];

  devTools = with pkgs; [
    docker-compose
    buildah
    skopeo
    lazydocker

    gh
  ];
in
{
  config = {
    programs = {
      television.enable = lib.mkDefault true;
      fzf.fuzzyCompletion = lib.mkDefault true;
    };

    environment.systemPackages = lib.subtractLists cfg.defaults.excludePackages (
      shellTools
      ++ tuiTools
      ++ (lib.optionals cfg.desktop.enable desktopTools)
      ++ (lib.optionals cfg.media.enable mediaTools)
      ++ (lib.optionals cfg.office.enable officeTools)
      ++ (lib.optionals cfg.development.enable devTools)
    );
  };
}
