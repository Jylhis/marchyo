# Helpers Enhancement Changelog

## Overview

Enhanced the `modules/flake/helpers.nix` to provide significantly more value to users of the Marchyo flake.

## What Was Added

### 1. Package Exposure (`marchyo.packages`)

Exposes Marchyo's custom packages in perSystem:
- `plymouth-marchyo-theme` - Custom Plymouth boot theme
- `hyprmon` - Hyprland monitor configuration TUI tool

Both are properly called using `pkgs.callPackage` for correct dependency injection.

### 2. Advanced Builders (`marchyo.builders`)

Extended builders with comprehensive options:
- `vm` - Build VM from a nixosConfiguration name
- `vmWithDisko` - Build VM with disko disk configuration
- `iso` - Build ISO installer image
- `toplevel` - Build system toplevel derivation

All builders include:
- Proper error handling with clear messages
- Available system listings in error messages
- Lazy evaluation (only evaluated when built)
- Specific error messages for missing features (disko, ISO profiles)

### 3. Color Scheme Access (`marchyo.colorSchemes`)

Provides direct access to all color schemes:
- All nix-colors schemes
- Custom Marchyo schemes (modus-vivendi-tinted, modus-operandi-tinted)
- Easy to use in perSystem context: `marchyo.colorSchemes.dracula.palette.base00`

### 4. Development Shell (`marchyo.devShells.default`)

Pre-configured development shell with:
- Nix tools: nix, nixfmt-rfc-style, nil, nix-tree, nix-diff, nvd
- Git tools: git, gh
- Formatting tools: treefmt, shellcheck, actionlint, deadnix, statix, yamlfmt
- Utilities: jq, ripgrep, fd
- Custom shell hook showing available commands and configured systems

### 5. Generator Apps (`marchyo.apps`)

Useful CLI applications:
- `show-systems` - Display all configured systems with details (architecture, hostname, users)
- `build-vm` - Interactive script to build and run VMs
- `list-colorschemes` - Browse all available color schemes (custom + nix-colors)

## Technical Details

### Type Safety
- All helpers respect `cfg.helpers.enable` option
- Proper use of `mkIf` to avoid infinite recursion
- Lazy evaluation throughout to prevent unnecessary builds

### Error Handling
Clear, actionable error messages:
```nix
throw "System '${systemName}' not found in nixosConfigurations. Available systems: ${
  lib.concatStringsSep ", " (lib.attrNames config.flake.nixosConfigurations)
}"
```

### Lazy Evaluation
All builders and package references are lazy:
- Functions return derivations (not evaluated until built)
- Attribute sets of derivations (only evaluated when accessed)
- No performance penalty for unused features

### Backward Compatibility
Legacy helpers maintained:
- `mkTestVm` - Marked as deprecated, suggests using `marchyo.builders.vm`
- `buildAllSystems` - Still available
- `getSystemConfig` - Still available
- `hasSystem` - Still available

## Documentation

Created comprehensive documentation:
- `/home/markus/Developer/marchyo/docs/HELPERS.md` - Complete guide with examples
- Updated `/home/markus/Developer/marchyo/templates/workstation/flake.nix` - Shows practical usage

## Usage Example

```nix
perSystem = { marchyo, ... }: {
  # Custom packages
  packages = {
    inherit (marchyo.packages) plymouth-marchyo-theme hyprmon;
    vm = marchyo.builders.vm "workstation";
  };

  # Development shell
  devShells.default = marchyo.devShells.default;

  # Useful apps
  apps = {
    show = marchyo.apps.show-systems;
    vm = marchyo.apps.build-vm;
    colors = marchyo.apps.list-colorschemes;
  };

  # Access color schemes
  # marchyo.colorSchemes.dracula.palette.base00
};
```

## Validation

All changes validated with:
- `nix fmt` - Code formatting (passed)
- `nix flake check` - Flake validation (passed)
- All existing tests pass
- No breaking changes to existing functionality

## Files Modified

1. `/home/markus/Developer/marchyo/modules/flake/helpers.nix` - Enhanced with new features (lines 1-305)
2. `/home/markus/Developer/marchyo/templates/workstation/flake.nix` - Updated with examples (lines 58-83)
3. `/home/markus/Developer/marchyo/docs/HELPERS.md` - New comprehensive documentation
4. `/home/markus/Developer/marchyo/docs/HELPERS_CHANGELOG.md` - This file

## Implementation Notes

### Package Exposure
- Uses `pkgs.callPackage` for proper dependency management
- Paths are relative to helpers.nix location (`../../packages/...`)
- Packages are instantiated in perSystem context (system-specific)

### Builder Implementation
- All builders check if system exists first
- Provide helpful error messages with available systems
- Check for feature availability (disko, ISO) before attempting to build
- Follow consistent error message format

### Color Schemes
- Directly imports colorschemes directory
- Merges with nix-colors.colorSchemes using `//` operator
- No duplication - single source of truth

### Development Shell
- Comprehensive tool selection for Nix development
- Useful shell hook with dynamic system listing
- Easy to extend via `inputsFrom`

### Apps
- All apps are proper flake apps with `type = "app"`
- Scripts use `writeShellScriptBin` for proper packaging
- Interactive with helpful output

## Benefits to Users

1. **Reduced Boilerplate**: Users can reference pre-packaged items instead of reimplementing
2. **Better Developer Experience**: Rich dev shell and useful apps
3. **Consistency**: Standardized way to build VMs, ISOs, and systems
4. **Discoverability**: Easy to explore color schemes and systems
5. **Type Safety**: All helpers properly typed and validated
6. **Error Prevention**: Clear error messages guide users to solutions
