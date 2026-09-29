{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs = {
    bash.enable = true;
    jq.enable = true;
    eza = {
      enable = true;
      git = config.programs.git.enable;
      icons = "auto";
      colors = "auto";
    };

    nh.enable = true;
    ripgrep = {
      enable = true;
      arguments = [ "--smart-case" ];
    };
    fd = {
      enable = true;

    };
    aria2.enable = true;
    tealdeer = {
      enable = true;
    };

  };

  # FreeDesktop trash CLI. Intentionally does NOT alias `rm`: changing rm
  # semantics in a shared flake surprises consumers. Linux-only (not macOS Trash).
  home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ pkgs.trash-cli ];
}
