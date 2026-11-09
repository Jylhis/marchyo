{ pkgs, ... }:
{
  languages.scala.enable = true;

  packages = [ pkgs.git ];
}
