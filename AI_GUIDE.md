# Marchyo - AI Assistant Guide

This document provides a comprehensive overview of the Marchyo project, serving as instructional context for AI assistants.

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
*   **nixos-hardware**: A collection of NixOS modules for specific hardware configurations.
*   **treefmt-nix**: Used for code formatting and quality checks.

## Quick Start

Add Marchyo to a user's `flake.nix`:

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

Alternatively, to bootstrap a new configuration using the workstation template:

```bash
nix flake init -t github:Jylhis/marchyo#workstation
```

## Available Options

ALL custom options are defined in `modules/nixos/options.nix` under the `marchyo.*` namespace.

### Feature Flags

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.desktop.enable` | `false` | Desktop environment (Niri, audio, bluetooth, fonts) |
| `marchyo.desktop.useWofi` | `false` | Use wofi instead of vicinae as the application launcher. |
| `marchyo.development.enable` | `false` | Development tools (git, docker, virtualization) |
| `marchyo.media.enable` | `false` | Media apps (auto-enabled by desktop) |
| `marchyo.office.enable` | `false` | Office apps (auto-enabled by desktop) |

### User Configuration

```nix
marchyo.users.<username> = {
  enable = true;  # default
  fullname = "Your Name";
  email = "your@email.com";
};
```

### Localization

| Option | Default | Example |
|--------|---------|---------|
| `marchyo.timezone` | `"Europe/Zurich"` | `"America/New_York"` |
| `marchyo.defaultLocale` | `"en_US.UTF-8"` | `"de_DE.UTF-8"` |

### Theming

```nix
marchyo.theme = {
  enable = true;  # default
  variant = "dark";  # or "light"
  scheme = "dracula";  # or any nix-colors scheme, or null for defaults
};
```
Default schemes: `modus-vivendi-tinted` (dark), `modus-operandi-tinted` (light).

### Keyboard & Input Methods

```nix
marchyo.keyboard = {
  layouts = [
    "us"                                    # Simple layout
    { layout = "fi"; }                      # Simple layout (explicit)
    { layout = "us"; variant = "intl"; }   # Layout with variant
    { layout = "cn"; ime = "pinyin"; }     # Chinese with Pinyin
    { layout = "jp"; ime = "mozc"; }       # Japanese with Mozc
    { layout = "kr"; ime = "hangul"; }     # Korean with Hangul
  ];
  options = [ "grp:win_space_toggle" ];    # Super+Space to switch
  autoActivateIME = true;                   # Auto-activate IME on switch
  imeTriggerKey = [ "Super+I" ];           # Manual IME toggle
};
```

### Graphics (GPU)

```nix
marchyo.graphics = {
  vendors = [ "intel" ];  # "intel", "amd", "nvidia"

  # NVIDIA-specific
  nvidia = {
    open = true;           # Open-source drivers (RTX 20xx+)
    powerManagement = false;
  };

  # Hybrid graphics (laptop with two GPUs)
  prime = {
    enable = true;
    intelBusId = "PCI:0:2:0";    # or amdgpuBusId
    nvidiaBusId = "PCI:1:0:0";
    mode = "offload";  # "offload", "sync", "reverse-sync"
  };
};
```
To find GPU bus IDs, run: `lspci | grep -E 'VGA|3D'`

## Breaking Changes & Migration

### `marchyo.inputMethod.enable` is REMOVED

The `marchyo.inputMethod.*` options have been removed and are no longer supported. Using `marchyo.inputMethod.enable = true;` will result in a build failure.

Please migrate your configuration to the new `marchyo.keyboard.layouts` structure.

**Old (will cause an error):**
```nix
marchyo.inputMethod.enable = true;
marchyo.inputMethod.enableCJK = true;
marchyo.keyboard.layouts = ["us" "fi"];
```

**New:**
To add Chinese input, for example:
```nix
marchyo.keyboard.layouts = [
  "us"
  "fi"
  { layout = "cn"; ime = "pinyin"; }
];
```

### Deprecated Options

The following options still work but will be removed in a future release:
- `marchyo.keyboard.variant`: Use `{ layout = "us"; variant = "intl"; }` in `marchyo.keyboard.layouts` instead.
- `marchyo.inputMethod.triggerKey`: Use `marchyo.keyboard.imeTriggerKey` instead.
- `marchyo.inputMethod.enableCJK`: Add CJK layouts to `marchyo.keyboard.layouts` instead.

## Development Guidelines

*   **Code Formatting**: All Nix files must be formatted using `nix fmt`.
*   **Testing**: All changes must pass tests run by `nix flake check`.
*   **Commit Messages**: Follow the conventional commit format.

### Commands

*   **Validate configuration and run tests**: `nix flake check`
*   **Format Nix code**: `nix fmt`
*   **Enter development shell**: `nix develop`
*   **Display flake outputs**: `nix flake show`
*   **List available tests**: `nix eval .#checks.x86_64-linux --apply builtins.attrNames`

### Architecture

*   **Module Organization**:
    *   NixOS system configuration modules: `modules/nixos/`
    *   Home Manager user configuration modules: `modules/home/`
    *   Shared modules (e.g., fontconfig, git): `modules/generic/`
*   **Adding New Options**: New custom options should be defined in `modules/nixos/options.nix` under the `marchyo.*` namespace.
*   **Adding New Modules**: Create the module file in the appropriate `modules/` subdirectory and import it into the corresponding `default.nix` file.
*   **Conditional Configuration**: Use `lib.mkIf cfg.*.enable` for conditional activation.
*   **Overridable Options**: Use `lib.mkDefault` for options that should be easily overridable.

## Flake Outputs Reference

- `nixosModules.default`: Main NixOS module (includes Home Manager).
- `homeModules.default`: Home Manager module only.
- `templates.workstation`: Starter template for a developer workstation.
- `overlays.default`: Nixpkgs overlay.
- `checks.{system}.*`: Tests.
- `formatter.{system}`: Code formatter.
