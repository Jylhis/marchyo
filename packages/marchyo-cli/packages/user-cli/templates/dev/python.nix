{ pkgs, ... }:
{
  languages.python = {
    enable = true;
    uv.enable = true;
  };

  packages = [ pkgs.git ];
}
