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
    # Qt QML tooling for editing shell/ (.qml): qmlls (LSP), qmlformat, qmllint.
    pkgs.qt6.qtdeclarative
  ];

  # qmlls resolves Quickshell.* / QtQuick imports from QML_IMPORT_PATH when
  # invoked with `-E' (the editor does). Quickshell installs its QML modules
  # under lib/qt-6/qml.
  env.QML_IMPORT_PATH = "${pkgs.quickshell}/lib/qt-6/qml";

  enterTest = ''
    just --version
    jq --version
    treefmt --version
    bun --version
  '';
}
