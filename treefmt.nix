{ pkgs, ... }:
let
  inherit (pkgs) lib;
  # qmllint over the shell tree, wired as a treefmt check. It resolves the
  # shell's `import qs.*` (per-directory qmldirs) via a temporary `qs -> shell`
  # alias root, plus Quickshell's and QtQuick's own qml modules, the CI/treefmt
  # analogue of the QML_IMPORT_PATH devenv.nix sets for the editor. Category
  # tuning and the MaxWarnings=0 threshold live in shell/.qmllint.ini (qmllint
  # auto-discovers it by walking up from each file). treefmt runs formatters from
  # the project root, so $PWD/shell is the tree.
  qmllint = pkgs.writeShellApplication {
    name = "marchyo-qmllint";
    runtimeInputs = [ pkgs.qt6.qtdeclarative ];
    text = ''
      root="$(mktemp -d)"
      trap 'rm -rf "$root"' EXIT
      ln -s "$PWD/shell" "$root/qs"
      qmllint \
        -I "$root" \
        -I ${pkgs.quickshell}/lib/qt-6/qml \
        -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
        "$@"
    '';
  };
in
{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
    statix.enable = true;
    yamlfmt.enable = true;
    typos.enable = true;
    actionlint.enable = true;
  };
  settings.formatter = {
    shellcheck = {
      excludes = [
        "**/.envrc"
        ".envrc"
      ];
      options = [
        "-s"
        "bash"
      ];
    };
    typos.excludes = [
      "**/*.png"
      "flake.lock"
      "devenv.lock"
      "site/bun.lock"
    ];
    # QML formatting via qmlformat (from Qt's qtdeclarative). Edits in place
    # (-i); treefmt passes the matched file list. Absolute command path so it
    # needs no PATH entry and works both in the devenv shell and in CI.
    qmlformat = {
      command = "${pkgs.qt6.qtdeclarative}/bin/qmlformat";
      options = [ "-i" ];
      includes = [ "*.qml" ];
    };
  }
  # qmllint pulls in Quickshell's QML modules (Linux-only); gate it so the
  # formatter output still evaluates on darwin, where the QML shell surfaces
  # (Wayland layer-shell) never run anyway. Kept lazy in the let binding so
  # pkgs.quickshell is never forced off Linux.
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    # Static QML check: fails on a non-existent-property assignment (the crash
    # class the offscreen harness can't reach, since it never loads the layer-
    # shell surfaces). See shell/.qmllint.ini for the enabled categories.
    qmllint = {
      command = "${qmllint}/bin/marchyo-qmllint";
      includes = [ "*.qml" ];
    };
  };
}
