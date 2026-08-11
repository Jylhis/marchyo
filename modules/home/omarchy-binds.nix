# Omarchy-parity keybinds (OMARCHY_PARITY.md Phase 2): monitor-control
# helpers, connectivity TUIs in floating terminals, and app-launch binds.
# Scripts follow the modules/home/window-toggles.nix writeShellApplication
# pattern; binds merge into the bind list the same way
# modules/home/webapps.nix does (home-manager concatenates the lists, order
# is irrelevant to Hyprland). The `terminal` Lua local and the org.omarchy.* floating
# window classes are defined in modules/home/hyprland.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.isLinux && (marchyoCfg.desktop.enable or false);
  devEnabled = marchyoCfg.development.enable or false;

  # Same resolution as the fileManager Lua local in modules/home/hyprland.nix: follow
  # marchyo.defaults.fileManager, fall back to xdg-open when unmanaged (null).
  fileManagerPackages = {
    inherit (pkgs) nautilus;
    inherit (pkgs.xfce) thunar;
  };
  fileManagerName = (marchyoCfg.defaults or { }).fileManager or "nautilus";
  fileManagerDeps =
    if fileManagerName == null then [ pkgs.xdg-utils ] else [ fileManagerPackages.${fileManagerName} ];

  # The monitor-scale cycle, laptop-panel toggle, and file-manager-at-cwd
  # helpers were absorbed into the marchyo CLI (`marchyo monitor
  # scale-cycle|laptop-toggle`, `marchyo launch file-manager` — same
  # hyprctl/procfs logic, packages/marchyo-cli commands/launch.ts). The
  # file-manager dependency stays installed for xdg-open to resolve.
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      # Backs the SUPER+ALT+Return work-session bind; not installed elsewhere.
      pkgs.tmux
      # xdg-open resolution for `marchyo launch file-manager` plus the
      # configured file manager itself.
      pkgs.xdg-utils
    ]
    ++ fileManagerDeps;

    wayland.windowManager.hyprland.settings.bind = [
      # Monitor controls
      # SUPER+/ (slash) is the password manager, so the scale cycle sits on the
      # adjacent backslash.
      (hlua.bindd "SUPER + backslash" "Cycle monitor scale" (hlua.exec "marchyo monitor scale-cycle"))
      (hlua.bindd "SUPER + CTRL + Delete" "Toggle laptop display" (
        hlua.exec "marchyo monitor laptop-toggle"
      ))

      # Connectivity TUIs (floating, omarchy setup-menu parity)
      # Same TUIs waybar's segments launch (wiremix/nmtui/bluetui); the
      # org.omarchy.* classes are matched by the floating-window tag rule in
      # modules/home/hyprland.nix. nmtui ships with the networkmanager package
      # (see modules/nixos/network.nix — Wi-Fi is on the wpa_supplicant
      # backend, not iwd; docs/known-issues.md).
      (hlua.bindd "SUPER + CTRL + A" "Audio mixer" (
        hlua.execInTerminalAs "org.omarchy.wiremix" "wiremix"
      ))
      (hlua.bindd "SUPER + CTRL + B" "Bluetooth manager" (
        hlua.execInTerminalAs "org.omarchy.bluetui" "bluetui"
      ))
      (hlua.bindd "SUPER + CTRL + W" "Wi-Fi manager" (hlua.execInTerminalAs "org.omarchy.nmtui" "nmtui"))

      # App launches
      (hlua.bindd "SUPER + ALT + return" "tmux Work session" (
        hlua.execInPlainTerminal "tmux new -A -s Work"
      ))
      (hlua.bindd "SUPER + ALT + SHIFT + F" "File manager at terminal cwd" (
        hlua.exec "marchyo launch file-manager"
      ))
    ]
    ++ lib.optionals devEnabled [
      # lazydocker is system-side via marchyo.development.enable (devTools in
      # modules/nixos/packages.nix), so the bind follows the same gate.
      (hlua.bindd "SUPER + ALT + D" "Docker TUI" (hlua.execInTerminal "lazydocker"))
    ];
  };
}
