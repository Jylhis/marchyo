# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marchyo is a NixOS configuration flake providing modular system and home-manager configurations. It's structured as a multi-purpose flake that manages NixOS systems, Home Manager configurations, and custom packages.

## Commands

### Build and Development
- `nix flake check` - Validate flake configuration and check for errors
- `nix flake show` - Display flake outputs (systems, packages, modules)
- `nix fmt` - Format Nix code using nixfmt (configured via treefmt)
- `nix develop` - Enter development shell with required tools

### Building Configurations
- `nix build .#nixosConfigurations.{hostname}` - Build specific NixOS configuration
- `nix build .#homeConfigurations.{username}` - Build specific Home Manager configuration

## Architecture

### Module Organization
- `modules/nixos/` - NixOS system configuration modules
- `modules/home/` - Home Manager user configuration modules
- `modules/generic/` - Shared modules between NixOS and Home Manager

### Key Modules
- `modules/nixos/options.nix` - Defines custom options under `marchyo.*` namespace
- `modules/nixos/default.nix` - Main NixOS module imports
- `modules/home/default.nix` - Main Home Manager module imports
- `lib/default.nix` - Custom utility functions

### Configuration Categories
NixOS modules are organized by function:
- System: boot, hardware, performance, security
- Desktop: hyprland, wayland, graphics, fonts
- Network: networking configuration
- Applications: office, media, containers
- Utilities: printing, locale, update management

Home Manager modules cover:
- Desktop environment: hyprland, waybar, wofi, mako
- Terminal: kitty, ghostty, shell configuration
- Development: git configuration
- System tools: btop, fastfetch

### Custom Options
The flake defines custom options under the `marchyo` namespace in `options.nix`:
- `marchyo.users.*` - User account configuration with email, fullname, and enable flags

### Dependencies
Key external dependencies:
- nixos-hardware for hardware-specific configurations
- home-manager for user environment management
- disko for disk partitioning (imported but not actively used in visible configs)
- treefmt-nix for code formatting
- nix-colors for Base16 theming system

### Colorschemes
Marchyo provides a unified theming system combining nix-colors Base16 schemes with custom colorschemes:

**Built-in nix-colors schemes** - Access 200+ schemes from the nix-colors library (e.g., `dracula`, `gruvbox-dark-medium`, `catppuccin-mocha`)

**Custom colorschemes** (in `colorschemes/` directory):
- `modus-operandi-tinted` - Light theme by Protesilaos Stavrou
- `modus-vivendi-tinted` - Dark theme by Protesilaos Stavrou

**Usage examples:**
```nix
# Use a nix-colors scheme
marchyo.theme = {
  enable = true;
  scheme = "dracula";
};

# Use a custom scheme
marchyo.theme = {
  enable = true;
  scheme = "modus-vivendi-tinted";
};

# Use a completely custom scheme
marchyo.theme = {
  enable = true;
  scheme = {
    slug = "my-custom";
    name = "My Custom Scheme";
    author = "Your Name";
    variant = "dark";
    palette = {
      base00 = "000000";
      # ... base01-base0F
    };
  };
};
```

Colorschemes are accessible via `flake.lib.marchyo.colorSchemes` for external use.

## Packages
- `packages/plymouth-marchyo-theme/` - Custom Plymouth boot theme

## Using Marchyo

### As a Library
Use `marchyo.lib.marchyo.mkNixosSystem` to create NixOS configurations with Marchyo modules:

```nix
{
  inputs.marchyo.url = "github:yourusername/marchyo";

  outputs = { marchyo, ... }: {
    nixosConfigurations.myhost = marchyo.lib.marchyo.mkNixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        { marchyo.desktop.enable = true; }
      ];
    };
  };
}
```

### Available Outputs
- `nixosModules.default` - Default NixOS module with Marchyo configuration
- `homeModules.default` - Default Home Manager module
- `lib.marchyo` - Utility functions including `mkNixosSystem`
- `diskoConfigurations` - Disk partitioning configurations
- `overlays.default` - Nixpkgs overlay
- `templates` - Project templates

## Development Notes
- The flake supports x86_64-linux systems
- All Nix files should follow the project's formatting standards enforced by treefmt
- Use `nix flake check` before committing to ensure configuration validity
- Custom utility functions are available in `lib/default.nix` including `mapListToAttrs` and `mkNixosSystem`
