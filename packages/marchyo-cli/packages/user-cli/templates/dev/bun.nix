{ pkgs, ... }:
{
  languages.javascript = {
    enable = true;
    bun.enable = true;
  };

  packages = [ pkgs.git ];
}
