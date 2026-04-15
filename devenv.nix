{ pkgs, inputs, ... }:
let
  treefmt = inputs.treefmt-nix.lib.mkWrapper pkgs (import ./treefmt.nix);
in
{
  languages.nix.enable = true;

  packages = [
    treefmt
    pkgs.just
    pkgs.jq
  ];

  enterTest = ''
    just --version
    jq --version
    treefmt --version
  '';
}
