{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.marchyo;
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

    # The compositor's GPU list (AQ_DRM_DEVICES) comes from
    # modules/nixos/graphics.nix, keyed off marchyo.graphics.primary.
  };
}
