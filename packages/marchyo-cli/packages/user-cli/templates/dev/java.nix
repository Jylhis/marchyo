{ pkgs, ... }:
{
  languages.java = {
    enable = true;
    gradle.enable = true;
  };

  packages = [ pkgs.git ];
}
