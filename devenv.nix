{ pkgs, ... }:
{
  languages.nix.enable = true;

  packages = with pkgs; [
    npins
    just
    jq
  ];
}
