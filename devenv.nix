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

  # qmlls/qmllint/qmlformat (all invoked with `-E' or from this env) resolve
  # Quickshell.* and QtQuick* imports from QML_IMPORT_PATH. Quickshell installs
  # its QML modules under lib/qt-6/qml; Qt's own modules (QtQuick, Layouts,
  # Window, ...) come from qtdeclarative's qml dir.
  env.QML_IMPORT_PATH = "${pkgs.quickshell}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";

  # `import qs.*' is a Quickshell convention: the config root is the `qs'
  # module namespace. Quickshell's own tooling support mirrors the scanned
  # .qml files into a runtime vfs and drops a .qmlls.ini symlink into shell/,
  # but that mirror contains no qmldir files, so qmlls still cannot resolve
  # qs.* through it. Instead, point the import path at a `qs -> shell' alias
  # directory: the checked-in per-directory qmldirs (module qs.Commons, qs.Bar,
  # ...) then resolve the same way the running shell resolves them.
  # enterShell runs as part of the shellHook, which `devenv shell', direnv, and
  # Emacs (devenv-env-mode evaluates the hook) all execute, so CLI and eglot
  # qmlls see identical import paths. `.devenv/' is gitignored.
  enterShell = ''
    mkdir -p "$DEVENV_ROOT/.devenv/qml-modules"
    ln -sfn "$DEVENV_ROOT/shell" "$DEVENV_ROOT/.devenv/qml-modules/qs"
    export QML_IMPORT_PATH="$DEVENV_ROOT/.devenv/qml-modules:$QML_IMPORT_PATH"
  '';

  enterTest = ''
    just --version
    jq --version
    treefmt --version
    bun --version
  '';
}
