{
  pkgs,
  lib,
  nixosConfig,
  sourceRoot,
}:
let
  gitHubUrl = "https://github.com/jylhis/marchyo";

  repoPrefix = toString sourceRoot + "/";
  stripRepo = p: lib.removePrefix repoPrefix (toString p);

  transformOptions =
    opt:
    opt
    // {
      declarations = map (d: {
        url = "${gitHubUrl}/blob/main/${stripRepo d}";
        name = stripRepo d;
      }) opt.declarations;
    };

  optionsDoc = pkgs.nixosOptionsDoc {
    options = { inherit (nixosConfig.options) marchyo; };
    inherit transformOptions;
  };

  libFiles = [
    {
      file = ../modules/generic/keyboard-lib.nix;
      category = "keyboard";
      description = "Shared keyboard helper functions.";
    }
  ];

  libMd = pkgs.runCommand "marchyo-lib-md" { nativeBuildInputs = [ pkgs.nixdoc ]; } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (f: ''
      nixdoc \
        --file ${f.file} \
        --category ${f.category} \
        --description "${f.description}" \
        > $out/${f.category}.md
    '') libFiles}
  '';
in
{
  optionsReference = pkgs.runCommand "marchyo-options-reference" { } ''
    mkdir -p $out
    cp ${optionsDoc.optionsCommonMark} $out/options.md
    cp ${optionsDoc.optionsJSON}/share/doc/nixos/options.json $out/options.json
  '';

  libReference = libMd;

  site = pkgs.runCommand "marchyo-docs-site" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
    mkdir -p $out

    cat > combined.md <<'HEADER'
    # Marchyo — Documentation

    Auto-generated reference for [Marchyo](${gitHubUrl}).

    - [Module Options](#module-options) — every `marchyo.*` option with type, default, example, and source link.
    - [Library Functions](#library-functions) — RFC-145 documented helper functions.

    ---

    # Module Options

    Import the main module in your NixOS, nix-darwin, or Home Manager configuration:

    ```nix
    {
      imports = [ marchyo.nixosModules.default ];
      marchyo.desktop.enable = true;
      marchyo.development.enable = true;
    }
    ```

    HEADER

    cat ${optionsDoc.optionsCommonMark} >> combined.md

    cat >> combined.md <<'SECTION2'

    ---

    # Library Functions

    Reusable Nix helpers documented with RFC-145 doc-comments and extracted by
    [nixdoc](https://github.com/nix-community/nixdoc).

    SECTION2

    cat ${libMd}/keyboard.md >> combined.md

    cat > $out/style.css <<'CSS'
    :root {
      --max-width: 52rem;
      --fg: #1a1a2e;
      --bg: #fafafa;
      --accent: #7C3AED;
      --code-bg: #f0f0f5;
      --border: #e2e2e8;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --fg: #e0e0e8;
        --bg: #16161e;
        --code-bg: #1e1e28;
        --border: #2a2a3a;
      }
    }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                   "Helvetica Neue", sans-serif;
      max-width: var(--max-width);
      margin: 2rem auto;
      padding: 0 1.5rem;
      color: var(--fg);
      background: var(--bg);
      line-height: 1.65;
    }
    h1 {
      font-size: 1.6rem;
      border-bottom: 2px solid var(--accent);
      padding-bottom: 0.4rem;
      margin-top: 2.5rem;
    }
    h1:first-of-type { margin-top: 0; }
    h2 {
      font-family: "SF Mono", "Fira Code", Menlo, Consolas, monospace;
      font-size: 1rem;
      font-weight: 600;
      margin-top: 2rem;
      padding: 0.4rem 0.6rem;
      background: var(--code-bg);
      border-left: 3px solid var(--accent);
      border-radius: 0 4px 4px 0;
      overflow-x: auto;
    }
    code {
      font-family: "SF Mono", "Fira Code", Menlo, Consolas, monospace;
      background: var(--code-bg);
      padding: 0.15rem 0.35rem;
      border-radius: 3px;
      font-size: 0.88em;
    }
    pre {
      background: var(--code-bg);
      padding: 1rem 1.2rem;
      border-radius: 6px;
      overflow-x: auto;
      border: 1px solid var(--border);
    }
    pre code { background: none; padding: 0; }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    hr { border: none; border-top: 1px solid var(--border); margin: 2.5rem 0; }
    ul { padding-left: 1.5rem; }
    p { margin: 0.6rem 0; }
    CSS

    pandoc combined.md \
      -o $out/index.html \
      --standalone \
      --metadata title="Marchyo — Documentation" \
      --css style.css \
      --highlight-style=kate \
      --wrap=none

    touch $out/.nojekyll
  '';
}
