{ pkgs, ... }:
{
  languages.ruby.enable = true;

  packages = [ pkgs.git ];
}
