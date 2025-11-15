# Documentation build system
{
  pkgs,
  lib,
  system,
  mdbook,
  nixosModules,
  homeModules,
}:

let
  # Generate options documentation
  optionsDocs = import ./generate-options.nix {
    inherit pkgs lib nixosModules homeModules;
  };

  # Prepare source directory with auto-generated content
  preparedSrc = pkgs.runCommand "docs-src" { } ''
    mkdir -p $out/src/reference/modules

    # Copy hand-written documentation
    cp -r ${./src}/* $out/src/ 2>/dev/null || true

    # Add auto-generated module options
    echo "# NixOS Module Options" > $out/src/reference/modules/nixos-options.md
    echo "" >> $out/src/reference/modules/nixos-options.md
    echo "This page documents all NixOS module options provided by Marchyo." >> $out/src/reference/modules/nixos-options.md
    echo "" >> $out/src/reference/modules/nixos-options.md
    cat ${optionsDocs.nixos} >> $out/src/reference/modules/nixos-options.md

    echo "# Home Manager Module Options" > $out/src/reference/modules/home-options.md
    echo "" >> $out/src/reference/modules/home-options.md
    echo "This page documents all Home Manager module options used by Marchyo." >> $out/src/reference/modules/home-options.md
    echo "" >> $out/src/reference/modules/home-options.md
    cat ${optionsDocs.home} >> $out/src/reference/modules/home-options.md

    # Copy book configuration and theme
    cp ${./book.toml} $out/book.toml
    ${lib.optionalString (builtins.pathExists ./theme) "cp -r ${./theme} $out/theme"}
  '';

in
mdbook.lib.buildMdBookProject {
  inherit system pkgs;
  src = preparedSrc;
  name = "marchyo-docs";
}
