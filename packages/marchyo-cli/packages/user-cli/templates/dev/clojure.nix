{ pkgs, ... }:
{
  languages.clojure.enable = true;

  packages = [ pkgs.git ];
}
