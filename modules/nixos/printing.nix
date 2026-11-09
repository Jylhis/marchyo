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
      # CUPS creates a temporary IPP Everywhere queue for each driverless printer.
      browsed.enable = lib.mkDefault false;
    };

    # Proxies driverless IPP-over-USB printers to localhost and advertises them over avahi.
    services.ipp-usb.enable = lib.mkDefault true;

    # Color management daemon. CUPS registers each printer/scanner with colord
    # over D-Bus (org.freedesktop.ColorManager); without it cupsd logs
    # "CreateProfile/CreateDevice failed ... not activatable" on every device event.
    services.colord.enable = lib.mkDefault true;

    environment.systemPackages = [ pkgs.system-config-printer ];
  };
}
