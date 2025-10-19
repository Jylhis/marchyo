{
  lib,
  pkgs,
  stdenvNoCC,
}:

let
  # API documentation content
  apiMarkdown = ''
    # Marchyo Library API Reference

    This documentation covers the public API of the Marchyo library functions available via `marchyo.lib.marchyo`.

    ## Core Library Functions

    ### `mkNixosSystem`

    Create a NixOS system configuration with marchyo modules automatically included.

    **Type**: `{ system, modules, extraSpecialArgs } -> NixOSConfiguration`

    **Parameters**:
    - `system` (required): System architecture (e.g., `"x86_64-linux"`, `"aarch64-linux"`)
    - `modules` (optional): List of additional NixOS modules to include. Default: `[]`
    - `extraSpecialArgs` (optional): Additional special arguments to pass to modules. Default: `{}`

    **Description**:

    This is a wrapper around `lib.nixosSystem` that reduces boilerplate by automatically including marchyo's module system and passing flake inputs as specialArgs.

    **Benefits**:
    - Automatically includes `marchyo.nixosModules.default`
    - Passes all flake inputs as `specialArgs`
    - Reduces boilerplate configuration
    - Enforces consistent base configuration

    **Examples**:

    ```nix
    # Basic usage
    nixosConfigurations.myhost = marchyo.lib.marchyo.mkNixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        { marchyo.desktop.enable = true; }
      ];
    };
    ```

    ```nix
    # With custom specialArgs
    nixosConfigurations.myserver = marchyo.lib.marchyo.mkNixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
      extraSpecialArgs = {
        myCustomInput = inputs.my-flake;
        hostname = "server";
      };
    };
    ```

    ---

    ### `mapListToAttrs`

    Map a list of strings to an attribute set by applying a function to each element.

    **Type**: `[String] -> (String -> a) -> AttrSet`

    **Parameters**:
    - First argument: List of strings to use as attribute names
    - Second argument: Function that takes a name and returns the attribute value

    **Description**:

    This is a convenience wrapper around `lib.listToAttrs` that simplifies the common pattern of converting a list of names into an attribute set where each name is transformed by a function.

    **Examples**:

    ```nix
    # Create packages from a list of names
    mapListToAttrs [ "hello" "cowsay" ] (name: pkgs.''${name})
    # => { hello = <derivation>; cowsay = <derivation>; }
    ```

    ```nix
    # Generate configuration files
    mapListToAttrs [ "dev" "prod" ] (env: {
      domain = "''${env}.example.com";
      port = if env == "prod" then 443 else 8080;
    })
    # => {
    #   dev = { domain = "dev.example.com"; port = 8080; };
    #   prod = { domain = "prod.example.com"; port = 443; };
    # }
    ```

    ---

    ## Color Utilities

    The `colors` module provides utilities for working with hex color codes, particularly useful for theming.

    ### `colors.withHash`

    Add a hash prefix to a hex color code.

    **Type**: `String -> String`

    **Parameters**:
    - `color`: Hex color code without the hash prefix (e.g., `"ff0000"`)

    **Returns**: Color code with hash prefix (e.g., `"#ff0000"`)

    **Example**:

    ```nix
    marchyo.lib.marchyo.colors.withHash "ff0000"
    # => "#ff0000"
    ```

    ---

    ### `colors.toRgb`

    Convert a hex color to CSS `rgb()` format.

    **Type**: `String -> String`

    **Parameters**:
    - `color`: 6-character hex color code without hash (e.g., `"ff0000"`)

    **Returns**: RGB color string (e.g., `"rgb(255, 0, 0)"`)

    **Examples**:

    ```nix
    marchyo.lib.marchyo.colors.toRgb "ff0000"
    # => "rgb(255, 0, 0)"
    ```

    ```nix
    marchyo.lib.marchyo.colors.toRgb "0000ff"
    # => "rgb(0, 0, 255)"
    ```

    ---

    ### `colors.toRgba`

    Convert a hex color to CSS `rgba()` format with alpha channel.

    **Type**: `String -> String -> String`

    **Parameters**:
    - `color`: 6-character hex color code without hash (e.g., `"ff0000"`)
    - `alpha`: Alpha/opacity value as a string (e.g., `"0.5"`, `"1"`)

    **Returns**: RGBA color string (e.g., `"rgba(255, 0, 0, 0.5)"`)

    **Examples**:

    ```nix
    marchyo.lib.marchyo.colors.toRgba "ff0000" "0.5"
    # => "rgba(255, 0, 0, 0.5)"
    ```

    ```nix
    marchyo.lib.marchyo.colors.toRgba "0000ff" "1"
    # => "rgba(0, 0, 255, 1)"
    ```

    ---

    ## Color Schemes

    Access to all available color schemes via `marchyo.lib.marchyo.colorSchemes`.

    **Description**:

    This attribute set combines:
    - **Built-in nix-colors schemes**: 200+ schemes from the nix-colors library
    - **Custom marchyo schemes**: `modus-vivendi-tinted`, `modus-operandi-tinted`

    **Structure**:

    Each color scheme follows the Base16 standard with the following structure:

    ```nix
    {
      slug = "scheme-name";
      name = "Human Readable Name";
      author = "Author Name";
      variant = "dark" or "light";
      palette = {
        base00 = "rrggbb";  # Default Background
        base01 = "rrggbb";  # Lighter Background
        # ... base02-base0F (16 colors total)
      };
    }
    ```

    **Usage**:

    ```nix
    # In NixOS configuration
    marchyo.theme = {
      enable = true;
      scheme = "modus-vivendi-tinted";
    };
    ```

    ```nix
    # In Home Manager
    colorScheme = marchyo.lib.marchyo.colorSchemes.dracula;
    ```

    ```nix
    # Access individual colors
    let
      colors = marchyo.lib.marchyo.colorSchemes.gruvbox-dark-medium.palette;
    in {
      programs.kitty.settings = {
        background = "#''${colors.base00}";
        foreground = "#''${colors.base05}";
        color0 = "#''${colors.base00}";
        color1 = "#''${colors.base08}";
        # etc.
      };
    }
    ```

    See the [Colorscheme Catalog](../colorschemes/) for a complete visual reference of all available schemes.

    ---

    ## Usage in Your Flake

    To use Marchyo library functions in your flake:

    ```nix
    {
      inputs.marchyo.url = "github:marchyo/marchyo";

      outputs = { marchyo, ... }: {
        # Use mkNixosSystem
        nixosConfigurations.myhost = marchyo.lib.marchyo.mkNixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };

        # Use utility functions
        packages.x86_64-linux = marchyo.lib.marchyo.mapListToAttrs
          [ "package1" "package2" ]
          (name: pkgs.writeText name "content");

        # Use color utilities
        packages.x86_64-linux.themed-config = pkgs.writeText "colors.css" \'\'
          :root {
            --bg: ''${marchyo.lib.marchyo.colors.withHash "282c34"};
            --fg: ''${marchyo.lib.marchyo.colors.toRgb "abb2bf"};
          }
        \'\';
      };
    }
    ```

    ---

    ## See Also

    - **[NixOS Options Reference](../options-nixos/)** - Configuration options for marchyo.*
    - **[Colorscheme Catalog](../colorschemes/)** - Visual preview of all color schemes
    - **[User Manual](../manual/)** - Complete guide to using Marchyo
  '';

  # Generate HTML from markdown
  apiHtml = pkgs.runCommand "marchyo-api-html" { buildInputs = [ pkgs.pandoc ]; } ''
    mkdir -p $out

    cat > api.md <<'EOF'
    ${apiMarkdown}
    EOF

    ${pkgs.pandoc}/bin/pandoc \
      --standalone \
      --toc \
      --toc-depth=3 \
      --template=${./templates/api.html} \
      --metadata title="Marchyo API Reference" \
      --from markdown \
      --to html5 \
      -o $out/index.html \
      api.md
  '';

in
stdenvNoCC.mkDerivation {
  name = "marchyo-api-docs";

  dontUnpack = true;

  buildPhase = ''
    cat > api.md <<'EOF'
    ${apiMarkdown}
    EOF
  '';

  installPhase = ''
    mkdir -p $out

    # Copy markdown version
    cp api.md $out/

    # Link HTML version
    ln -s ${apiHtml} $out/html
  '';

  meta = {
    description = "API documentation for Marchyo library functions";
    maintainers = [ ];
  };
}
