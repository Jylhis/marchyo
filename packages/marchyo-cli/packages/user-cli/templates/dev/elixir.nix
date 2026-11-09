{ pkgs, ... }:
{
  languages.elixir.enable = true;

  packages = [ pkgs.git ];
}
