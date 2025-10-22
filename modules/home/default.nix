{
  imports = [
    ../generic/fontconfig.nix
    ../generic/git.nix
    ../generic/shell.nix
    ../generic/packages.nix
    ./_1password.nix
    ./theme.nix
    ./bat.nix
    ./btop.nix
    ./fastfetch.nix
    ./fzf.nix
    ./xournalpp.nix
    ./git.nix
    ./help.nix
    ./hypridle.nix
    ./hyprland.nix
    ./hyprlock.nix
    ./hyprpaper.nix
    ./k9s.nix
    ./kitty.nix
    ./lazygit.nix
    ./locale.nix
    ./mako.nix
    ./packages.nix
    ./shell.nix
    ./starship.nix
    ./waybar.nix
    ./vicinae.nix
    ./wofi.nix
  ];

  # Backup existing files with this extension when home-manager overwrites them
  home.backupFileExtension = "backup";
}
