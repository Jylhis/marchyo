# Declarative Homebrew (nix-darwin manages the Brewfile; Homebrew itself must
# already be installed on the host). Casks declared by consumers merge additively
# with the curated list below; use `lib.mkForce` to drop one of these defaults.
{ lib, ... }:
{
  homebrew = {
    enable = lib.mkDefault true;

    onActivation = {
      autoUpdate = lib.mkDefault true;
      # Safe default: do not remove undeclared apps. Consumers can opt into
      # "zap" (or "uninstall") downstream.
      cleanup = lib.mkDefault "none";
    };

    # Minimal curated set of GUI apps that need native macOS .app bundles.
    # Preference order: HM module > nix-darwin > homebrew.
    casks = [
      "google-chrome"
      "spotify"
      "vlc"
    ];
  };
}
