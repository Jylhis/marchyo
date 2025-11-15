# Setup Development Environment

Configure development tools and environments.

## Enable Development Mode

```nix
marchyo.development.enable = true;
```

This enables:
- Git with LFS
- Docker & libvirtd
- Development packages (gcc, make, cmake)
- Direnv for project environments

## Docker

### Basic Usage

```bash
# Docker is already running
docker ps

# Your user is in the docker group
docker run hello-world
```

### Docker Compose

```bash
docker-compose up -d
```

### Lazy Docker (TUI)

```bash
lazydocker
```

Keybinding: `Super + D`

## Direnv for Project Environments

Create `.envrc` in your project:

```bash
use flake
```

Then:

```bash
direnv allow
```

## Language-Specific Setup

### Python

Add to your project `flake.nix`:

```nix
{
  description = "Python project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          python311
          python311Packages.pip
          python311Packages.virtualenv
        ];
      };
    };
}
```

### Node.js

```nix
devShells.${system}.default = pkgs.mkShell {
  packages = with pkgs; [
    nodejs_20
    nodePackages.npm
    nodePackages.pnpm
  ];
};
```

### Rust

```nix
devShells.${system}.default = pkgs.mkShell {
  packages = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy
  ];
};
```

## IDE Configuration

### VS Code

Install via home-manager:

```nix
home.packages = [ pkgs.vscode ];
```

### Neovim

Add to configuration:

```nix
programs.neovim = {
  enable = true;
  viAlias = true;
  vimAlias = true;
  plugins = with pkgs.vimPlugins; [
    # Your plugins
  ];
};
```

## Resources

- [Direnv documentation](https://direnv.net/)
- [Nix dev environments](https://nix.dev/tutorials/declarative-and-reproducible-developer-environments)
