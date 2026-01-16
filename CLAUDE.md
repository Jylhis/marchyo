# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marchyo is a NixOS configuration flake providing modular system and home-manager configurations. It manages NixOS systems, Home Manager configurations, and custom packages.

## Commands

### Build and Development
- `nix flake check` - Run all tests (module evaluation, lib tests, formatting) - completes in under 1 minute
- `nix flake show` - Display flake outputs
- `nix fmt` - Format code using treefmt (nixfmt, deadnix, statix, shellcheck, yamlfmt)
- `nix develop` - Enter development shell

### Testing
- `nix flake check` - Run all tests (recommended for rapid iteration)
- `nix eval .#checks.x86_64-linux --apply builtins.attrNames` - List available tests

Tests include module evaluation tests (`eval-*`) and lib function tests (`test-*`).

## Architecture

### Module Organization
- `modules/nixos/` - NixOS system configuration modules
- `modules/home/` - Home Manager user configuration modules
- `modules/generic/` - Shared modules between NixOS and Home Manager (fontconfig, git, shell, packages)

### Key Files
- `flake.nix` - Main flake definition with inputs, outputs, and module composition
- `modules/nixos/options.nix` - Defines ALL custom options under `marchyo.*` namespace
- `modules/nixos/default.nix` - Imports all NixOS modules
- `modules/home/default.nix` - Imports all Home Manager modules
- `colorschemes/default.nix` - Custom Base16 schemes (modus-vivendi-tinted, modus-operandi-tinted)

### Feature Flags & Auto-Configuration

Marchyo uses feature flags that trigger auto-configuration modules:

**`marchyo.desktop.enable`** (in `modules/nixos/desktop-config.nix`)
- Configures: printing, bluetooth, audio (pipewire), fonts, graphics, power management, XDG portals
- Sets `marchyo.office.enable` and `marchyo.media.enable` to `true` by default
- Enables services: blueman, geoclue2, tumbler, upower, locate, gnome-keyring

**`marchyo.development.enable`** (in `modules/nixos/development-config.nix`)
- Configures: git (with LFS), direnv, docker (with auto-prune), libvirtd (with QEMU KVM)
- Installs development tools: gh, gnumake, cmake, gcc, docker-compose, lazydocker, virt-manager, sqlite, curl, wget, netcat, nmap, tcpdump, jq, yq, tree, ripgrep, fd, eza
- Enables KVM kernel modules and development documentation

### Custom Options Structure

ALL custom options are defined in `modules/nixos/options.nix`:

- **User config** (`marchyo.users.<name>.*`): `enable`, `name`, `fullname`, `email`
- **Feature flags**: `marchyo.desktop.enable`, `marchyo.development.enable`, `marchyo.media.enable`, `marchyo.office.enable`
- **Theming** (`marchyo.theme.*`): `enable`, `variant` (light/dark), `scheme`
- **Localization**: `marchyo.timezone`, `marchyo.defaultLocale`
- **Keyboard** (`marchyo.keyboard.*`): `layouts`, `autoActivateIME`, `imeTriggerKey`, `options`

**Keyboard layouts** support both simple strings (`"us"`, `"fi"`) and attribute sets for IME:
```nix
marchyo.keyboard.layouts = [
  "us"
  { layout = "cn"; ime = "pinyin"; }
  { layout = "jp"; ime = "mozc"; }
];
```

### Theme System

Themes merge nix-colors schemes with custom Marchyo schemes:
- Default dark: `modus-vivendi-tinted`
- Default light: `modus-operandi-tinted`
- Access via: `config._module.args.colorSchemes` (NixOS) or `extraSpecialArgs.colorSchemes` (Home Manager)

### Flake Outputs
- `nixosModules.default` - Main NixOS module (includes home-manager, determinate, Marchyo modules)
- `homeModules.default` - Home Manager module
- `lib.marchyo` - Utility library (colors from `lib/colors.nix`)
- `lib.marchyo.colorSchemes` - Custom colorschemes
- `overlays.default` - Nixpkgs overlay
- `templates.workstation` - Template with desktop + development setup
- `checks.{system}.*` - Tests
- `formatter.{system}` - treefmt configuration

## Development Guidelines

### System Support
- Supported systems: x86_64-linux, aarch64-linux
- Some packages (e.g., Spotify) are platform-specific

### Code Quality
- **Always run `nix fmt` before committing**
- **Always run `nix flake check` before committing**

### Module Development
- **Adding new options**: Edit `modules/nixos/options.nix`
- **Adding new modules**:
  1. Create module file in `modules/nixos/`, `modules/home/`, or `modules/generic/`
  2. Import it in the corresponding `default.nix` file
- **Auto-config patterns**: See `desktop-config.nix` and `development-config.nix` for examples

### Common Patterns
- Use `lib.mkDefault` for options that should be overridable
- Use `lib.mkIf cfg.*.enable` for conditional module activation
- Generic modules in `modules/generic/` are shared between NixOS and Home Manager

## Known Issues / Future Work

| Location | Type | Issue | Suggested Fix |
|----------|------|-------|---------------|
| `modules/home/waybar.nix:144` | FIXME | `on-click = "kitty -e btop"` hardcoded | Use `$terminal` variable for consistency |
| `modules/home/waybar.nix:257` | TODO | `DarkLight.sh` script missing | Implement theme toggle or remove `custom/light_dark` module |
| `modules/nixos/options.nix` | Deprecated | `keyboard.variant`, `inputMethod.*` options | Keep for migration guidance, mark removal date |

### Deprecated Options

The following options in `modules/nixos/options.nix` are deprecated and will be removed in a future release:

- `marchyo.keyboard.variant` - Use `{ layout = "us"; variant = "intl"; }` in `marchyo.keyboard.layouts` instead
- `marchyo.inputMethod.*` - Migrated to `marchyo.keyboard.layouts` with IME support

## Documentation Maintenance

### LLM.md

The `LLM.md` file is intended for end users to share with their AI assistants. When making changes that affect user-facing configuration:

1. **Update LLM.md** when:
   - Adding/removing/changing `marchyo.*` options
   - Deprecating options (add to "Breaking Changes & Migration" section)
   - Changing default values
   - Adding new feature flags

2. **Keep LLM.md concise** - focus on configuration options and common tasks, not internal architecture
