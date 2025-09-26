{ pkgs, ... }:
{
  config = {
    boot.plymouth = {
      themePackages = [ pkgs.plymouth-omarchy-theme ];
      theme = "omarchy";
    };
  };
}
