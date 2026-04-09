# Shared treefmt configuration
# Used by flake.nix, default.nix, and devenv.nix
{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    actionlint.enable = false;
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
