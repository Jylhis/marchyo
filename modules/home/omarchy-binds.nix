# Omarchy-parity keybinds (OMARCHY_PARITY.md Phase 2): monitor-control
# helpers, connectivity TUIs in floating terminals, and app-launch binds.
# Scripts follow the modules/home/window-toggles.nix writeShellApplication
# pattern; binds merge into the bindd list the same way
# modules/home/webapps.nix does (home-manager concatenates the lists, order
# is irrelevant to Hyprland). `$terminal` and the org.omarchy.* floating
# window classes are defined in modules/home/hyprland.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.isLinux && (marchyoCfg.desktop.enable or false);
  devEnabled = marchyoCfg.development.enable or false;

  # Same resolution as $fileManager in modules/home/hyprland.nix: follow
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

    wayland.windowManager.hyprland.settings.bindd = [
      # --- Monitor controls ---
      # SUPER+/ (slash) is the password manager, so the scale cycle sits on the
      # adjacent backslash.
      "SUPER, backslash, Cycle monitor scale, exec, marchyo monitor scale-cycle"
      "SUPER CTRL, Delete, Toggle laptop display, exec, marchyo monitor laptop-toggle"

      # --- Connectivity TUIs (floating, omarchy setup-menu parity) ---
      # Same TUIs waybar's segments launch (wiremix/nmtui/bluetui); the
      # org.omarchy.* classes are matched by the floating-window tag rule in
      # modules/home/hyprland.nix. nmtui ships with the networkmanager package
      # (see modules/nixos/network.nix — Wi-Fi is on the wpa_supplicant
      # backend, not iwd; docs/known-issues.md).
      "SUPER CTRL, A, Audio mixer, exec, $terminal --class=org.omarchy.wiremix -e wiremix"
      "SUPER CTRL, B, Bluetooth manager, exec, $terminal --class=org.omarchy.bluetui -e bluetui"
      "SUPER CTRL, W, Wi-Fi manager, exec, $terminal --class=org.omarchy.nmtui -e nmtui"

      # --- App launches ---
      "SUPER ALT, return, tmux Work session, exec, $terminal -e tmux new -A -s Work"
      "SUPER ALT SHIFT, F, File manager at terminal cwd, exec, marchyo launch file-manager"
    ]
    ++ lib.optionals devEnabled [
      # lazydocker is system-side via marchyo.development.enable (devTools in
      # modules/nixos/packages.nix), so the bind follows the same gate.
      "SUPER ALT, D, Docker TUI, exec, $terminal --class=org.omarchy.terminal -e lazydocker"
    ];
  };
}
