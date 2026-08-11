{ pkgs, ... }:
{
  services.printing = {
    enable = true;
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
  services.colord.enable = true;
}
