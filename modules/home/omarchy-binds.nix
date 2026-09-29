# Omarchy-parity keybinds: monitor-control helpers, connectivity TUIs in
# floating terminals, and app-launch binds. The `terminal` Lua local and the
# org.omarchy.* floating window classes are defined in modules/home/hyprland.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && (marchyoCfg.desktop.enable or false);
  devEnabled = marchyoCfg.development.enable or false;

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

    wayland.windowManager.hyprland.settings.bind = [
      # SUPER+/ (slash) is the password manager, so the scale cycle sits on the
      # adjacent backslash.
      (hlua.bindd "SUPER + backslash" "Cycle monitor scale" (hlua.exec "marchyo monitor scale-cycle"))
      (hlua.bindd "SUPER + CTRL + Delete" "Toggle laptop display" (
        hlua.exec "marchyo monitor laptop-toggle"
      ))

      # Connectivity TUIs in floating terminals; the org.omarchy.* classes are
      # matched by the floating-window tag rule in modules/home/hyprland.nix.
      (hlua.bindd "SUPER + CTRL + A" "Audio mixer" (
        hlua.execInTerminalAs "org.omarchy.wiremix" "wiremix"
      ))
      (hlua.bindd "SUPER + CTRL + B" "Bluetooth manager" (
        hlua.execInTerminalAs "org.omarchy.bluetui" "bluetui"
      ))
      (hlua.bindd "SUPER + CTRL + W" "Wi-Fi manager" (hlua.execInTerminalAs "org.omarchy.nmtui" "nmtui"))

      (hlua.bindd "SUPER + ALT + return" "tmux Work session" (
        hlua.execInPlainTerminal "tmux new -A -s Work"
      ))
      (hlua.bindd "SUPER + ALT + SHIFT + F" "File manager at terminal cwd" (
        hlua.exec "marchyo launch file-manager"
      ))
    ]
    ++ lib.optionals devEnabled [
      # lazydocker is installed system-side via marchyo.development.enable, so
      # the bind follows the same gate.
      (hlua.bindd "SUPER + ALT + D" "Docker TUI" (hlua.execInTerminal "lazydocker"))
    ];
  };
}
