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
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && ((marchyoCfg.desktop or { }).enable or false);
  fileManager = (marchyoCfg.defaults or { }).fileManager or null;
  enabled = desktopEnabled && fileManager == "nautilus";

  localsendEnabled = ((marchyoCfg.services or { }).localsend or { }).enable or false;

  # LocalSend has no CLI to pre-fill files, so the script just launches the app,
  # detached (setsid) so it survives Nautilus exiting.
  sendWithLocalsend = pkgs.writeShellApplication {
    name = "send-with-localsend";
    runtimeInputs = [ pkgs.util-linux ]; # setsid
    text = ''
      setsid --fork ${lib.getExe pkgs.localsend} >/dev/null 2>&1
    '';
  };
in
{
  config = lib.mkIf enabled {
    home.packages = [ pkgs.nautilus-open-any-terminal ];

    # mkDefault so a host running a different terminal can override.
    dconf.settings."com/github/stunkymonkey/nautilus-open-any-terminal".terminal =
      lib.mkDefault "ghostty";

    # Only when LocalSend ships (modules/nixos/localsend.nix).
    home.file.".local/share/nautilus/scripts/Send with LocalSend" = lib.mkIf localsendEnabled {
      source = lib.getExe sendWithLocalsend;
    };
  };
}
