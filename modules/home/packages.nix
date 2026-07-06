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
    };

    nh.enable = true;
    ripgrep.enable = true;
    fd = {
      enable = true;

    };
    aria2.enable = true;
    tealdeer = {
      enable = true;
    };

  };

  # Recoverable deletes via the FreeDesktop trash (`trash`, `trash-put`,
  # `trash-list`, `trash-restore`). Intentionally does NOT alias `rm` — silently
  # changing rm semantics in a shared flake surprises consumers. Linux-only:
  # trash-cli implements the FreeDesktop spec, not the macOS Trash.
  home.packages = lib.optionals (!pkgs.stdenv.isDarwin) [ pkgs.trash-cli ];
}
