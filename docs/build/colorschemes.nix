{
  lib,
  pkgs,
  stdenvNoCC,
}:

let
  catalogLib = import ../lib/catalog.nix { inherit lib pkgs; };

  # Load all colorschemes
  schemesDir = ../../colorschemes;
  colorschemes = catalogLib.discoverColorschemes schemesDir;

  # Base16 color names and their descriptions
  base16Colors = {
    base00 = "Default Background";
    base01 = "Lighter Background";
    base02 = "Selection Background";
    base03 = "Comments, Invisibles";
    base04 = "Dark Foreground";
    base05 = "Default Foreground";
    base06 = "Light Foreground";
    base07 = "Light Background";
    base08 = "Red (Variables, Tags)";
    base09 = "Orange (Integers, Constants)";
    base0A = "Yellow (Classes, Search)";
    base0B = "Green (Strings)";
    base0C = "Cyan (Support, Regex)";
    base0D = "Blue (Functions, Methods)";
    base0E = "Purple (Keywords, Storage)";
    base0F = "Brown (Deprecated)";
  };

  # Generate color palette HTML
  generatePalette =
    palette:
    ''
      <div class="color-palette">
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: color:
            ''
              <div class="color-swatch">
                <div class="color-box" style="background-color: #${color};"></div>
                <div class="color-info">
                  <span class="color-name">${name}</span>
                  <span class="color-hex">#${color}</span>
                  <span class="color-desc">${base16Colors.${name} or ""}</span>
                </div>
              </div>
            ''
          ) palette
        )}
      </div>
    '';

  # Generate HTML for a single colorscheme
  schemeToHTML =
    name: scheme:
    ''
      <div class="card">
        <h2>${scheme.name or name}</h2>
        <div class="meta">
          <span class="badge badge-${scheme.variant or "unknown"}">${scheme.variant or "unknown"}</span>
          <span><strong>Author:</strong> ${scheme.author or "Unknown"}</span>
          <span><strong>Slug:</strong> <code>${scheme.slug or name}</code></span>
        </div>

        <h3>Color Palette</h3>
        ${generatePalette scheme.palette}

        <h3>Usage</h3>
        <div class="usage-example">
          <p><strong>In your NixOS configuration:</strong></p>
          <div class="code-block">
            <pre><code>{
  imports = [ marchyo.nixosModules.default ];

  marchyo.theme = {
    enable = true;
    scheme = "${scheme.slug or name}";
  };
}</code></pre>
          </div>

          <p><strong>In Home Manager configuration:</strong></p>
          <div class="code-block">
            <pre><code>{
  imports = [ marchyo.homeModules.default ];

  colorScheme = marchyo.lib.marchyo.colorSchemes.${scheme.slug or name};
}</code></pre>
          </div>

          <p><strong>Access individual colors in Nix:</strong></p>
          <div class="code-block">
            <pre><code>let
  colors = marchyo.lib.marchyo.colorSchemes.${scheme.slug or name}.palette;
in {
  # Use colors.base00, colors.base08, etc.
  programs.kitty.settings = {
    background = "#''${colors.base00}";
    foreground = "#''${colors.base05}";
  };
}</code></pre>
          </div>
        </div>
      </div>
    '';

  # Additional CSS for colorscheme catalog
  extraCSS = ''
    .color-desc {
      color: #95a5a6;
      font-size: 0.8rem;
      font-style: italic;
      margin-top: 0.25rem;
    }

    .color-swatch {
      flex-direction: column;
      align-items: flex-start;
    }

    .color-box {
      width: 100%;
      height: 80px;
      margin-bottom: 0.5rem;
    }
  '';

  # Generate complete HTML document
  htmlContent = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Marchyo Colorscheme Catalog</title>
      <style>
        ${catalogLib.catalogCSS}
        ${extraCSS}
      </style>
    </head>
    <body>
      <header>
        <h1>Marchyo Colorscheme Catalog</h1>
        <p class="subtitle">Custom Base16 color schemes for consistent theming</p>
        <p class="meta">Total schemes: ${toString (builtins.length (builtins.attrNames colorschemes))}</p>
      </header>

      <main>
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList schemeToHTML colorschemes)}
      </main>

      <footer>
        <p>Generated from <a href="https://github.com/marchyo/marchyo">Marchyo</a> using Nix</p>
        <p>This catalog is automatically generated from colorscheme definitions.</p>
        <p>All colorschemes follow the <a href="https://github.com/chriskempson/base16">Base16</a> standard.</p>
      </footer>
    </body>
    </html>
  '';

in
stdenvNoCC.mkDerivation {
  name = "marchyo-colorscheme-catalog";

  dontUnpack = true;

  buildPhase = ''
    cat > index.html <<'EOF'
    ${htmlContent}
    EOF
  '';

  installPhase = ''
    mkdir -p $out
    cp index.html $out/
  '';

  meta = {
    description = "Auto-generated catalog of Marchyo colorschemes with visual previews";
    maintainers = [ ];
  };
}
