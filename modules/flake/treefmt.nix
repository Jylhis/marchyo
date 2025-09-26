_:
{
  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";

        programs.nixfmt.enable = pkgs.lib.meta.availableOn pkgs.stdenv.buildPlatform pkgs.nixfmt-rfc-style.compiler;
        programs.nixfmt.package = pkgs.nixfmt-rfc-style;
        programs.actionlint.enable = true;
        programs.deadnix.enable = true;
        programs.shellcheck.enable = true;
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
        programs.statix.enable = true;
      };
    };
}
