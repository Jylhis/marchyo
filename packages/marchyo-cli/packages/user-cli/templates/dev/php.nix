{ pkgs, ... }:
{
  languages.php.enable = true;

  packages = [ pkgs.git ];
}
