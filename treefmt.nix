{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
    statix.enable = true;
    yamlfmt.enable = true;
  };
  settings.formatter.shellcheck = {
    excludes = [
      "**/.envrc"
      ".envrc"
    ];
    options = [
      "-s"
      "bash"
    ];
  };
}
