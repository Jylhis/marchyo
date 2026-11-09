# Packages behind the Omarchy-parity binds in lib/keybinds.nix: tmux for the
# work session and the file manager for `marchyo launch file-manager`.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && (marchyoCfg.desktop.enable or false);

  # Follow marchyo.defaults.fileManager, falling back to xdg-open when null.
  fileManagerPackages = {
    inherit (pkgs) nautilus;
    inherit (pkgs.xfce) thunar;
  };
  fileManagerName = (marchyoCfg.defaults or { }).fileManager or "nautilus";
  fileManagerDeps =
    if fileManagerName == null then [ pkgs.xdg-utils ] else [ fileManagerPackages.${fileManagerName} ];

  # The file-manager dependency stays installed for xdg-open to resolve.
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      # Backs the SUPER+ALT+Return work-session bind; not installed elsewhere.
      pkgs.tmux
      # xdg-open resolution for `marchyo launch file-manager`.
      pkgs.xdg-utils
    ]
    ++ fileManagerDeps;
  };
}
