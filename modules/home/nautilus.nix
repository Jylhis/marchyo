# Nautilus integration: open-a-terminal-here (ghostty) and a LocalSend script.
# Active only when the desktop is enabled and Nautilus is the selected file
# manager (marchyo.defaults.fileManager); the package itself installs via
# modules/nixos/defaults.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.isLinux && ((marchyoCfg.desktop or { }).enable or false);
  fileManager = (marchyoCfg.defaults or { }).fileManager or null;
  enabled = desktopEnabled && fileManager == "nautilus";

  localsendEnabled = ((marchyoCfg.services or { }).localsend or { }).enable or false;

  # Nautilus scripts get the selection via NAUTILUS_SCRIPT_SELECTED_FILE_PATHS,
  # but LocalSend has no CLI to pre-fill files declaratively — so the script is
  # a simple launch of the app, detached into its own session (setsid) so it
  # survives Nautilus exiting.
  sendWithLocalsend = pkgs.writeShellApplication {
    name = "send-with-localsend";
    runtimeInputs = [
      pkgs.localsend
      pkgs.util-linux # setsid
    ];
    text = ''
      setsid --fork localsend >/dev/null 2>&1
    '';
  };
in
{
  config = lib.mkIf enabled {
    # Adds an "Open in Terminal" context-menu entry to Nautilus.
    home.packages = [ pkgs.nautilus-open-any-terminal ];

    # Point the context-menu entry at marchyo's terminal (ghostty, the same
    # default as hyprland.nix's $terminal). mkDefault so a host running a
    # different terminal can override the key.
    dconf.settings."com/github/stunkymonkey/nautilus-open-any-terminal".terminal =
      lib.mkDefault "ghostty";

    # "Send with LocalSend" under Nautilus' Scripts menu (only when LocalSend
    # itself ships, see modules/nixos/localsend.nix). The store binary is
    # already executable, so a symlink via `source` suffices.
    home.file.".local/share/nautilus/scripts/Send with LocalSend" = lib.mkIf localsendEnabled {
      source = lib.getExe sendWithLocalsend;
    };
  };
}
