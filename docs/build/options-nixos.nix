{
  lib,
  pkgs,
  nixosModules,
}:

let
  inherit (lib)
    evalModules
    hasPrefix
    mkForce
    ;

  # Repository information for generating GitHub links
  repoUrl = "https://github.com/marchyo/marchyo";
  repoBranch = "main";

  # Function to transform file paths to GitHub URLs
  # This cleans up declaration sites to show GitHub links instead of /nix/store paths
  transformDeclarations =
    opt:
    opt
    // {
      declarations = map (
        decl:
        if builtins.isString decl then
          let
            # Extract relative path by removing common prefixes
            stripped =
              if hasPrefix "/nix/store/" decl then
                # For store paths, try to extract the relative path after the hash
                let
                  parts = lib.splitString "/" decl;
                  # Find where "marchyo" appears and take everything after
                  findMarchyo =
                    list:
                    if list == [ ] then
                      null
                    else if (builtins.head list) == "marchyo" || hasPrefix "marchyo-" (builtins.head list) then
                      lib.concatStringsSep "/" (builtins.tail list)
                    else
                      findMarchyo (builtins.tail list);
                  relative = findMarchyo parts;
                in
                if relative != null then relative else decl
              else
                decl;
          in
          {
            url = "${repoUrl}/blob/${repoBranch}/${stripped}";
            name = stripped;
          }
        else
          decl
      ) opt.declarations;
    };

  # Base module configuration with only option definitions, no config
  # This prevents evaluation errors when generating documentation

  # Evaluate NixOS modules to extract marchyo.* options
  nixosEval = evalModules {
    modules = [
      {
        _module.check = false;
        nixpkgs.hostPlatform = pkgs.system;
      }
      nixosModules
    ];
  };

  # Generate documentation for NixOS options (marchyo.* and documentation.marchyo.*)
  nixosOptionsDocs = pkgs.nixosOptionsDoc {
    options = nixosEval.options;
    transformOptions = transformDeclarations;
    warningsAreErrors = false;
  };

  # Generate HTML documentation
  optionsHtml = pkgs.runCommand "marchyo-options-nixos-html" { buildInputs = [ pkgs.pandoc ]; } ''
    mkdir -p $out

    # Convert CommonMark to HTML
    ${pkgs.pandoc}/bin/pandoc \
      --standalone \
      --toc \
      --toc-depth=4 \
      --template=${./templates/options.html} \
      --metadata title="Marchyo NixOS Configuration Options" \
      --from commonmark \
      --to html5 \
      -o $out/index.html \
      ${nixosOptionsDocs.optionsCommonMark}
  '';

in
pkgs.runCommand "marchyo-options-nixos" { } ''
  mkdir -p $out

  # Copy markdown version
  cp ${nixosOptionsDocs.optionsCommonMark} $out/options.md

  # Copy JSON version
  cp ${nixosOptionsDocs.optionsJSON}/share/doc/nixos/options.json $out/options.json

  # Link HTML version
  ln -s ${optionsHtml} $out/html
''
