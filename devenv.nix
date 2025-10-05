{ pkgs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "🚀 Welcome to Marchyo development environment";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    # Nix development tools
    nil # Nix LSP
    nixd # Alternative Nix LSP
    nixpkgs-fmt # Nix formatter
    alejandra # Alternative Nix formatter
    statix # Nix linter
    deadnix # Find dead Nix code
    nix-tree # Visualize Nix dependencies
    nix-diff # Compare Nix derivations
    nvd # Nix version diff

    # Documentation tools
    mdbook # Documentation generator
    mdbook-mermaid # Mermaid diagrams for mdbook

    # Git tools
    git-cliff # Changelog generator

    # Testing utilities
    nixos-rebuild # For testing configurations

    # Utilities
    jq # JSON processor
    yq # YAML processor
  ];

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo "$GREET"
    echo ""
    echo "Available commands:"
    echo "  check        - Run nix flake check"
    echo "  fmt          - Format all Nix files"
    echo "  test         - Run all tests"
    echo "  test-nixos   - Run NixOS VM tests"
    echo "  test-home    - Run Home Manager tests"
    echo "  lint         - Run statix linter"
    echo "  clean        - Remove dead code with deadnix"
    echo "  docs         - Build documentation"
    echo "  docs-serve   - Serve documentation locally"
    echo "  changelog    - Generate changelog"
  '';

  scripts.check.exec = ''
    echo "🔍 Running flake check..."
    nix flake check
  '';

  scripts.fmt.exec = ''
    echo "✨ Formatting Nix files..."
    nix fmt
  '';

  scripts.test.exec = ''
    echo "🧪 Running all tests..."
    nix flake check
  '';

  scripts.test-nixos.exec = ''
    echo "🧪 Running NixOS tests..."
    nix build .#checks.x86_64-linux.nixos-desktop --print-build-logs
    nix build .#checks.x86_64-linux.nixos-development --print-build-logs
    nix build .#checks.x86_64-linux.nixos-users --print-build-logs
  '';

  scripts.test-home.exec = ''
    echo "🧪 Running Home Manager tests..."
    nix build .#checks.x86_64-linux.home-git --print-build-logs
    nix build .#checks.x86_64-linux.home-packages --print-build-logs
  '';

  scripts.lint.exec = ''
    echo "🔎 Linting Nix files..."
    statix check .
  '';

  scripts.clean.exec = ''
    echo "🧹 Finding dead Nix code..."
    deadnix .
  '';

  scripts.docs.exec = ''
    echo "📚 Building documentation..."
    if [ -d "docs/book" ]; then
      cd docs/book && mdbook build
    else
      echo "❌ Documentation directory not found"
      echo "Create docs/book directory and book.toml first"
    fi
  '';

  scripts.docs-serve.exec = ''
    echo "📚 Serving documentation on http://localhost:3000..."
    if [ -d "docs/book" ]; then
      cd docs/book && mdbook serve
    else
      echo "❌ Documentation directory not found"
      echo "Create docs/book directory and book.toml first"
    fi
  '';

  scripts.changelog.exec = ''
    echo "📝 Generating changelog..."
    git-cliff --output CHANGELOG.md
    echo "✅ Changelog updated"
  '';

  enterShell = ''
    hello
  '';

  # https://devenv.sh/languages/
  languages.nix.enable = true;

  # https://devenv.sh/pre-commit-hooks/
  pre-commit.hooks = {
    nixpkgs-fmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    # Check for TODO/FIXME comments
    check-merge-conflicts.enable = true;
    # Prevent committing secrets
    detect-private-keys.enable = true;
  };

  # https://devenv.sh/processes/
  # processes.docs.exec = "mdbook serve docs/book";

  # See full reference at https://devenv.sh/reference/options/
}
