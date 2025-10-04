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
- `modules/flake/` - Flake-specific modules and utilities

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

## Packages
- `packages/plymouth-marchyo-theme/` - Custom Plymouth boot theme

## Development Notes
- The flake supports both x86_64-linux and aarch64-linux systems
- All Nix files should follow the project's formatting standards enforced by treefmt
- Use `nix flake check` before committing to ensure configuration validity
- Custom utility functions are available in `lib/default.nix` including `mapListToAttrs`
