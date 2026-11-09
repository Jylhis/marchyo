{ pkgs, ... }:
{
  languages.dotnet.enable = true;

  packages = [ pkgs.git ];
}
