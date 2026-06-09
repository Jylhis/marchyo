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
    ];
  };
}
