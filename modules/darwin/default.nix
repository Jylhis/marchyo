# nix-darwin module for Marchyo
# Imports platform-agnostic options, nix settings, and generic modules.
# Desktop/Wayland/systemd modules are NixOS-only and not imported here.
{
  imports = [
    ../nixos/options.nix
    ../nixos/nix-settings.nix
    ../generic/theme.nix
    ../generic/fontconfig.nix
    ../generic/git.nix
    ../generic/shell.nix
    ../generic/packages.nix
  ];
}
