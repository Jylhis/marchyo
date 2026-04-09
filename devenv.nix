{ pkgs, ... }:
{
  packages = with pkgs; [
    npins
    just
    nil
    nix-diff
  ];

  pre-commit.hooks = {
    nixfmt-rfc-style.enable = true;
    deadnix.enable = true;
    statix.enable = true;
    shellcheck.enable = true;
  };
}
