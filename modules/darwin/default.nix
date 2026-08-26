# nix-darwin module for Marchyo
# Imports platform-agnostic options, nix settings, and generic modules.
# Desktop/Wayland/systemd modules are NixOS-only and not imported here.
{
  imports = [
    ../nixos/options
    ../nixos/nix-settings.nix
    ../users/darwin.nix
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
