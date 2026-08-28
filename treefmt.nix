{ pkgs, ... }:
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
  };
}
