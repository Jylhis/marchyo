{ pkgs, ... }:
{
  languages.ocaml.enable = true;

  packages = [ pkgs.git ];
}
