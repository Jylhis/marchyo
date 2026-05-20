{ pkgs, inputs, ... }:
let
  treefmt = inputs.treefmt-nix.lib.mkWrapper pkgs (import ./treefmt.nix);
  marchyo-cli = pkgs.callPackage ./packages/marchyo-cli/package.nix { };
in
{
  languages.nix.enable = true;

  packages = [
    treefmt
    pkgs.just
    pkgs.jq
    pkgs.bun
    marchyo-cli
  ];

  enterTest = ''
    just --version
    jq --version
    treefmt --version
    bun --version
  '';
}
