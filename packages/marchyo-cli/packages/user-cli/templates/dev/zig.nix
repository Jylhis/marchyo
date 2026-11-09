{ pkgs, ... }:
{
  languages.zig.enable = true;

  packages = [ pkgs.git ];
}
