{ pkgs, ... }:
{
  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  packages = [ pkgs.git ];
}
