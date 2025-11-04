{ lib, pkgs }:
rec {
  # Scan a directory for package.nix files and extract metadata
  # Returns: { name -> { meta, path } }
  discoverPackages =
    packagesDir:
    let
      # Read all subdirectories in packages/
      entries = builtins.readDir packagesDir;

      # Filter for directories that contain package.nix
      packageDirs = lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (packagesDir + "/${name}/package.nix")
      ) entries;

      # For each package, call it and extract metadata
      mkPackageInfo =
        name:
        let
          pkg = pkgs.callPackage (packagesDir + "/${name}/package.nix") { };
        in
        {
          inherit name;
          inherit (pkg) meta;
          pname = pkg.pname or name;
          version = pkg.version or "unknown";
          description = pkg.meta.description or "No description provided";
          homepage = pkg.meta.homepage or null;
          license = pkg.meta.license.shortName or "unknown";
          mainProgram = pkg.meta.mainProgram or pkg.pname or name;
          path = "${name}/package.nix";
        };
    in
    lib.mapAttrs (name: _: mkPackageInfo name) packageDirs;

  # Load all colorschemes from a directory
  # Returns: { name -> scheme }
  discoverColorschemes =
    schemesDir:
    let
      schemes = import schemesDir;
    in
    lib.mapAttrs (name: scheme: scheme // { inherit name; }) schemes;

  # Generate HTML color swatch
  # color: "rrggbb" format
  generateColorSwatch =
    name: color:
    ''
      <div class="color-swatch">
        <div class="color-box" style="background-color: #${color};"></div>
        <div class="color-info">
          <span class="color-name">${name}</span>
          <span class="color-hex">#${color}</span>
        </div>
      </div>
    '';

  # Generate CSS for the catalogs
  catalogCSS = ''
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
      background: #f5f5f5;
    }

    @media (prefers-color-scheme: dark) {
      body {
        background: #1a1a1a;
        color: #e0e0e0;
      }
      .card {
        background: #2a2a2a !important;
        border-color: #444 !important;
      }
      header {
        background: #2a2a2a !important;
      }
      h1, h2, h3 {
        color: #e0e0e0 !important;
      }
      .subtitle, .meta {
        color: #aaa !important;
      }
      .code-block {
        background: #1a1a1a !important;
        border-color: #444 !important;
      }
    }

    header {
      background: white;
      padding: 2rem;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      margin-bottom: 2rem;
    }

    h1 {
      color: #2c3e50;
      margin-bottom: 0.5rem;
    }

    .subtitle {
      color: #7f8c8d;
      font-size: 1.1rem;
    }

    .card {
      background: white;
      padding: 1.5rem;
      margin-bottom: 1.5rem;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .card h2 {
      color: #2c3e50;
      margin-bottom: 0.5rem;
      font-size: 1.5rem;
    }

    .card h3 {
      color: #34495e;
      margin-bottom: 0.5rem;
      font-size: 1.2rem;
    }

    .meta {
      color: #7f8c8d;
      font-size: 0.9rem;
      margin-bottom: 1rem;
    }

    .meta span {
      margin-right: 1rem;
    }

    .meta a {
      color: #3498db;
      text-decoration: none;
    }

    .meta a:hover {
      text-decoration: underline;
    }

    .description {
      margin-bottom: 1rem;
    }

    .code-block {
      background: #f8f9fa;
      border: 1px solid #dee2e6;
      border-radius: 4px;
      padding: 1rem;
      margin: 1rem 0;
      overflow-x: auto;
    }

    code {
      font-family: "Fira Code", "Consolas", "Monaco", monospace;
      font-size: 0.9rem;
    }

    pre {
      margin: 0;
    }

    .color-palette {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 1rem;
      margin: 1.5rem 0;
    }

    .color-swatch {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }

    .color-box {
      width: 60px;
      height: 60px;
      border-radius: 6px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
      border: 2px solid rgba(0,0,0,0.1);
    }

    .color-info {
      display: flex;
      flex-direction: column;
    }

    .color-name {
      font-weight: 600;
      color: #2c3e50;
      font-size: 0.9rem;
    }

    .color-hex {
      font-family: "Fira Code", monospace;
      color: #7f8c8d;
      font-size: 0.85rem;
    }

    .usage-example {
      margin-top: 1rem;
    }

    footer {
      text-align: center;
      margin-top: 3rem;
      padding: 2rem;
      color: #7f8c8d;
      font-size: 0.9rem;
    }

    .badge {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      border-radius: 12px;
      font-size: 0.85rem;
      font-weight: 600;
      margin-right: 0.5rem;
    }

    .badge-light {
      background: #ecf0f1;
      color: #2c3e50;
    }

    .badge-dark {
      background: #34495e;
      color: white;
    }
  '';
}
