{ pkgs, inputs, ... }:
let
  treefmt = inputs.treefmt-nix.lib.mkWrapper pkgs (import ./treefmt.nix);
in
{
  languages.nix.enable = true;

  packages = [
    treefmt
    pkgs.npins
    pkgs.just
    pkgs.jq
  ];

  enterTest = ''
    npins --version
    just --version
    jq --version
    treefmt --version
  '';
}
