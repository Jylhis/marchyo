{ pkgs, ... }:
{
  languages.deno.enable = true;

  packages = [ pkgs.git ];
}
