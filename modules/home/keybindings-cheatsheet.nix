{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  cfg = config.marchyo.keybindingsHelp;
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # The cheatsheet logic (hyprctl binds -j → modmask decode → fzf overlay)
  # lives in the marchyo CLI (`marchyo keybindings`, absorbed from the old
  # marchyo-keybindings script). Reading the binds at runtime means the
  # sheet always reflects the actual running config, including any binds
  # added by downstream consumers. fzf is the CLI's presentation dependency.
in
{
  options.marchyo.keybindingsHelp = {
    enable = mkEnableOption "on-screen Hyprland keybinding cheat sheet (SUPER+K)" // {
      default = true;
    };
  };

  config = mkIf (desktopEnabled && cfg.enable) {
    home.packages = [ pkgs.fzf ];

    # Reuse the existing floating-terminal class so the overlay picks up the
    # centered floating-window rule from hyprland.nix without a new windowrule.
    wayland.windowManager.hyprland.settings.bind = [
      (hlua.bindd "SUPER + K" "Keybindings cheat sheet" (hlua.execInTerminal "marchyo keybindings"))
    ];
  };
}
