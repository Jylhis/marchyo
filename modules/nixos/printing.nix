{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
      gutenprint
      gutenprintBin
      brlaser
    ];
  };

}
