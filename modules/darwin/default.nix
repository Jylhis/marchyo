# Hand-curated import list: desktop/Wayland/systemd modules are NixOS-only and
# must not be imported here.
{
  imports = [
    ../nixos/options
    ../nixos/nix-settings.nix
    ../generic/theme.nix
    ../generic/stylix.nix
    ../generic/fontconfig.nix
    ../generic/git.nix
    ../generic/shell.nix
    ../generic/packages.nix
    ./users.nix
    ./shell.nix
    ./home.nix
    ./system-defaults.nix
    ./homebrew.nix
    ./wallpaper.nix
  ];
}
