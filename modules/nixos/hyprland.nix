{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.marchyo;
  hasNvidia = builtins.elem "nvidia" (config.marchyo.graphics.vendors or [ ]);
in
{
  config = lib.mkIf cfg.desktop.enable {
    programs.hyprland = {
      enable = lib.mkDefault true;
      xwayland.enable = lib.mkDefault true;
      withUWSM = lib.mkDefault true;
    };

    xdg.portal = {
      enable = lib.mkDefault true;
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

    environment.sessionVariables = lib.mkIf hasNvidia {
      # Point Hyprland at the right GPU (dGPU is typically card1, iGPU card0).
      WLR_DRM_DEVICES = lib.mkDefault "/dev/dri/card1:/dev/dri/card0";
    };
  };
}
