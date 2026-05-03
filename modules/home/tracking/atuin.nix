# Per-user atuin shell history configuration.
#
# Enables programs.atuin with local-only storage, fuzzy search, and
# shell integration. Complementary to modules/nixos/tracking/shell.nix
# which installs the system package and writes a reference /etc config.
{
  osConfig,
  lib,
  ...
}:
let
  trackingCfg = osConfig.marchyo.tracking or { };
  enabled = (trackingCfg.enable or false) && (trackingCfg.shell.enable or false);
in
{
  config = lib.mkIf enabled {
    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        search_mode = "fuzzy";
        filter_mode = "global";
        filter_mode_shell_up_key_binding = "session";
        workspaces = true;
        style = "auto";
        inline_height = 20;
        show_preview = true;
        show_help = false;
        store_failed = true;
        secrets_filter = true;
        # Local-only: no sync server.
        sync_address = "";
        stats.common_subcommands = [
          "git"
          "docker"
          "kubectl"
          "nix"
          "cargo"
          "just"
          "npm"
          "pnpm"
          "go"
        ];
      };
    };
  };
}
