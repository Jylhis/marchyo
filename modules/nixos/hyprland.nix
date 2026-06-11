{
  config,
  pkgs,
  lib,
  ...
}:
let
  hasNvidia = builtins.elem "nvidia" (config.marchyo.graphics.vendors or [ ]);
in
{
  # Hyprland is a desktop surface: only install it (and its portals) when the
  # desktop stack is enabled. greetd in boot.nix is gated the same way, so a
  # desktop-disabled host gets neither the compositor nor a way to launch it.
  config = lib.mkIf config.marchyo.desktop.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xdg-desktop-portal
      ];
      config = {
        common = {
          default = [
            "hyprland"
            "gtk"
          ];
        };
        hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        };
      };
    };

    # NVIDIA-specific Hyprland settings
    environment.sessionVariables = lib.mkIf hasNvidia {
      # Help Hyprland find the right GPU (dGPU typically card1, iGPU card0)
      WLR_DRM_DEVICES = lib.mkDefault "/dev/dri/card1:/dev/dri/card0";
    };
  };
}
