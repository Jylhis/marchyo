# Desktop-only: CUPS plus the colour-management daemon it talks to.
#
# Sole owner of services.printing.enable — modules/nixos/desktop-config.nix
# deliberately does not set it, so there is one definition rather than two
# competing on priority.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.desktop.enable {
    services.printing = {
      enable = lib.mkDefault true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
        gutenprint
        brlaser
      ];
    };

    # Color management daemon. CUPS registers each printer/scanner with colord
    # over D-Bus (org.freedesktop.ColorManager); without it cupsd logs
    # "CreateProfile/CreateDevice failed ... not activatable" on every device event.
    services.colord.enable = lib.mkDefault true;
  };
}
