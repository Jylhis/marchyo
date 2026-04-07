# Shell history tracking via atuin (local-only).
#
# Installs the atuin binary system-wide. Per-user configuration is expected
# to come from Home Manager (programs.atuin) or manual `atuin import` +
# `~/.config/atuin/config.toml`. A reference config snippet is written to
# /etc/atuin/config.toml as documentation.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.enable) {
    environment.systemPackages = [ pkgs.atuin ];

    environment.etc."atuin/config.toml".text = ''
      # Reference configuration for marchyo.tracking.shell.
      # Copy to ~/.config/atuin/config.toml or set via Home Manager.
      search_mode = "fuzzy"
      workspaces = true
      store_failed = true
      secrets_filter = true
      # Local-only: no sync server.
      sync_address = ""

      [stats]
      common_subcommands = ["git", "docker", "kubectl", "nix", "cargo", "just"]
    '';
  };
}
