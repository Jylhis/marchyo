# GEMINI.md - Marchyo Project Overview

This document provides a comprehensive overview of the Marchyo project, serving as instructional context for future interactions with AI assistants.

## Project Overview

Marchyo is a modular NixOS configuration flake designed to provide a curated set of system and Home Manager configurations with sensible defaults. It aims to simplify the management of NixOS systems, user environments, and custom packages by offering a highly organized and configurable structure.

**Key Features:**

*   **Modular Architecture**: Configurations are broken down into small, manageable modules for various aspects like desktop, development, media, and office environments, as well as generic shared configurations.
*   **Feature Flags**: Simple boolean flags (`marchyo.desktop.enable`, `marchyo.development.enable`, etc.) allow users to enable entire stacks of related functionality and tools, which then auto-configure various services and packages.
*   **Home Manager Integration**: Seamlessly manages user-specific configurations, applications, and dotfiles.
*   **Hardware Support**: Integrates with `nixos-hardware` for common devices and provides detailed graphics configuration options, including NVIDIA-specific settings and NVIDIA PRIME support for hybrid graphics.
*   **Configurable Options**: A rich set of custom options under the `marchyo.*` namespace allows fine-grained control over various aspects of the system and user environment, including user definitions, localization, and extensive keyboard layout and input method management.

**Core Technologies:**

*   **NixOS**: The Linux distribution built on Nix, providing declarative and reproducible system configurations.
*   **Nix Flakes**: The modern way to define, use, and share Nix projects, managing inputs and outputs.
*   **Home Manager**: A Nix-based tool for managing user environments declaratively.
*   **nix-colors**: A library for integrating Base16 color schemes into Nix configurations.
*   **nixos-hardware**: A collection of NixOS modules for specific hardware configurations.
*   **treefmt-nix**: Used for code formatting and quality checks.

## Building and Running

Marchyo is intended to be integrated into a user's `flake.nix` or used as a template for new NixOS configurations.

### Integration Example (from `README.md`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        marchyo.nixosModules.default
        ./hardware-configuration.nix
        {
          marchyo.desktop.enable = true;
          marchyo.development.enable = true;
          marchyo.users.myuser = {
            fullname = "Your Name";
            email = "your.email@example.com";
          };
        }
      ];
    };
  };
}
```

### Quick Start with Template:

To bootstrap a new configuration using the workstation template:

```bash
nix flake init -t github:Jylhis/marchyo#workstation
```

### Development Commands:

*   **Validate configuration and run tests**:
    ```bash
    nix flake check
    ```
*   **Format Nix code**:
    ```bash
    nix fmt
    ```
*   **Enter development shell**:
    ```bash
    nix develop
    ```
*   **Display flake outputs**:
    ```bash
    nix flake show
    ```
*   **List available tests**:
    ```bash
    nix eval .#checks.x86_64-linux --apply builtins.attrNames
    ```

## Development Conventions

*   **Code Formatting**: All Nix files must be formatted using `nix fmt`. This command utilizes `treefmt` with `nixfmt`, `deadnix`, `statix`, `shellcheck`, and `yamlfmt`.
*   **Testing**: All changes must pass tests run by `nix flake check`. This includes module evaluation tests (`eval-*`) and library function tests (`test-*`).
*   **Commit Messages**: Follow the conventional commit format.
*   **Module Organization**:
    *   NixOS system configuration modules: `modules/nixos/`
    *   Home Manager user configuration modules: `modules/home/`
    *   Shared modules (e.g., fontconfig, git): `modules/generic/`
*   **Adding New Options**: New custom options should be defined in `modules/nixos/options.nix` under the `marchyo.*` namespace.
*   **Adding New Modules**: Create the module file in the appropriate `modules/` subdirectory (`nixos`, `home`, or `generic`) and import it into the corresponding `default.nix` file.
*   **Conditional Configuration**: Use `lib.mkIf cfg.*.enable` for conditional activation of modules or configurations based on feature flags.
*   **Overridable Options**: Use `lib.mkDefault` for options that should be easily overridable by users.

## Project Structure Highlights

*   **`flake.nix`**: The central definition of the flake, managing inputs (dependencies like `nixpkgs`, `home-manager`, `nix-colors`) and outputs (NixOS modules, Home Manager modules, overlays, library functions, tests, formatter).
*   **`modules/nixos/default.nix`**: Aggregates all NixOS-specific configuration modules.
*   **`modules/home/default.nix`**: Aggregates all Home Manager-specific user configuration modules.
*   **`modules/nixos/options.nix`**: Defines the entire custom configuration API for Marchyo under the `marchyo.*` namespace, including feature flags, graphics settings, theming, and keyboard options.
*   **`lib/default.nix`**: Exposes utility functions, including color manipulation functions from `lib/colors.nix`.
*   **`lib/colors.nix`**: Provides helper functions for converting hex colors to RGB/RGBA formats and managing color strings.
*   **`tests/`**: Contains various tests, including lightweight unit tests for library functions (`lib-tests.nix`) and module evaluation tests.
*   **`templates/workstation/`**: Provides a ready-to-use template for a full developer workstation setup.
*   **`colorschemes/`**: Contains custom Base16 color schemes used by the theming system.

## Important Notes for AI Assistants

*   **User-Facing Changes**: If making changes that affect user-facing configuration (adding/removing/changing `marchyo.*` options, deprecating options, changing default values, adding new feature flags), update `LLM.md` accordingly.
*   **Deprecated Options**: Be aware of deprecated options (e.g., `marchyo.keyboard.variant`, `marchyo.inputMethod.*`) as noted in `modules/nixos/options.nix` and `CLAUDE.md`. Provide migration guidance when applicable.
*   **Code Quality**: Always ensure `nix fmt` and `nix flake check` pass after any modifications.
*   **Modular Approach**: When adding new functionality, adhere to the existing modular structure by creating new `.nix` files in the appropriate `modules/` subdirectories and importing them into the respective `default.nix` files.
