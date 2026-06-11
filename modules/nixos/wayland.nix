{ config, lib, ... }:
{
  # Wayland session env vars — only meaningful under the desktop session.
  config = lib.mkIf config.marchyo.desktop.enable {
    environment.sessionVariables = {
      # Conservative Wayland settings
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      # NixOS Electron wrapper injects --ozone-platform=wayland via this variable
      NIXOS_OZONE_WL = "1";
      # Java AWT/Swing apps (JetBrains IDEs) need this on tiling Wayland compositors
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };
}
