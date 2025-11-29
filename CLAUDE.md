# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marchyo is a NixOS configuration flake providing modular system and home-manager configurations. It's structured as a multi-purpose flake that manages NixOS systems, Home Manager configurations, and custom packages.

## Commands

### Build and Development
- `nix flake check` - Run all lightweight tests (module evaluation, formatting, etc.) - completes in under 1 minute
- `nix flake show` - Display flake outputs (systems, packages, modules)
- `nix fmt` - Format Nix code using treefmt (nixfmt, deadnix, statix, actionlint, shellcheck, yamlfmt)
- `nix develop` - Enter development shell with required tools

### Testing
- `nix flake check` - Run lightweight evaluation tests (recommended for rapid iteration)
- `nix build .#vmTests.x86_64-linux.{test-name}` - Run specific VM-based test (1-5 minutes, ~2GB RAM)
- `nix eval .#checks.x86_64-linux --apply builtins.attrNames` - List available lightweight tests
- `nix eval .#vmTests.x86_64-linux --apply builtins.attrNames` - List available VM tests

Available VM tests: `nixos-desktop`, `nixos-development`, `nixos-users`, `nixos-git`, `home-git`, `home-packages`, `integration-all-features`

## Architecture

### Module Organization
- `modules/nixos/` - NixOS system configuration modules (33 modules)
- `modules/home/` - Home Manager user configuration modules (26 modules)
- `modules/generic/` - Shared modules between NixOS and Home Manager (fontconfig, git, shell, packages)

### Key Files
- `flake.nix` - Main flake definition with inputs, outputs, and module composition
- `modules/nixos/options.nix` - Defines ALL custom options under `marchyo.*` namespace
- `modules/nixos/default.nix` - Imports all NixOS modules (single source of truth for module list)
- `modules/home/default.nix` - Imports all Home Manager modules (single source of truth)
- `lib/default.nix` - Exports color utilities from `lib/colors.nix`
- `colorschemes/default.nix` - Exports custom Base16 schemes (modus-vivendi-tinted, modus-operandi-tinted)

### Configuration Categories
**NixOS modules** organized by function:
- **System foundation**: boot, hardware, performance, security, system, nix-settings
- **Desktop stack**: desktop-config (auto-setup module), hyprland, wayland, graphics, fonts, plymouth, hyprlock
- **Development stack**: development-config (auto-setup module), containers
- **Network & services**: network, printing
- **Applications**: media, office (via desktop-config)
- **User experience**: locale, keyboard, fcitx5, help, update-diff
- **External integrations**: _1password

**Home Manager modules** organized by function:
- **Desktop environment**: hyprland, waybar, wofi, vicinae, mako, hyprpaper, hypridle, hyprlock, screenshot
- **Terminal & shell**: kitty, shell, starship, bat, fzf
- **Development tools**: git, lazygit, k9s
- **System utilities**: btop, fastfetch, help
- **Theming & localization**: theme, locale, keyboard, fcitx5
- **Applications**: xournalpp, dropbox
- **External integrations**: _1password

**Generic modules** (shared between NixOS and Home Manager):
- fontconfig, git, shell, packages

### Feature Flags & Auto-Configuration Modules

Marchyo uses feature flags that trigger auto-configuration modules to enable groups of related functionality:

**`marchyo.desktop.enable`** (implemented in `modules/nixos/desktop-config.nix`)
- When enabled, automatically configures: printing, bluetooth, audio (pipewire), fonts, graphics, power management, XDG portals
- Sets `marchyo.office.enable` and `marchyo.media.enable` to `true` by default (can be overridden)
- Enables desktop services: blueman, geoclue2, tumbler, upower, locate, gnome-keyring

**`marchyo.development.enable`** (implemented in `modules/nixos/development-config.nix`)
- When enabled, automatically configures: git (with LFS), direnv, docker (with auto-prune), libvirtd (with QEMU KVM)
- Installs development tools: gh, gnumake, cmake, gcc, docker-compose, lazydocker, virt-manager, sqlite, curl, wget, netcat, nmap, tcpdump, jq, yq, tree, ripgrep, fd, eza
- Enables KVM kernel modules and development documentation

**`marchyo.office.enable`** and **`marchyo.media.enable`**
- Implemented in individual modules (`modules/nixos/office.nix`, `modules/nixos/media.nix`)
- Automatically enabled when desktop is enabled (but can be disabled explicitly)

### Custom Options Structure

ALL custom options are defined in `modules/nixos/options.nix`. Key option categories:

**User configuration** (`marchyo.users.<name>.*`)
- `enable`, `name`, `fullname`, `email` - User account metadata passed to git and other tools

**Feature flags** (trigger auto-configuration modules)
- `marchyo.desktop.enable` - Desktop environment
- `marchyo.desktop.useWofi` - Use wofi instead of vicinae launcher
- `marchyo.development.enable` - Development tools
- `marchyo.media.enable` - Media applications
- `marchyo.office.enable` - Office applications

**Theming** (`marchyo.theme.*`)
- `enable` - Enable nix-colors theming system (default: true)
- `variant` - "light" or "dark" (default: "dark"), selects default scheme when scheme is null
- `scheme` - String (scheme name), attrs (custom scheme), or null (uses variant default)

**Localization** (`marchyo.*`)
- `timezone` - System timezone (default: "Europe/Zurich")
- `defaultLocale` - System locale (default: "en_US.UTF-8")

**Keyboard & Input Methods** (`marchyo.keyboard.*`)

Marchyo provides a unified input system where keyboard layouts and input methods are configured together through `marchyo.keyboard.layouts`.

- `layouts` - List of keyboard layouts and input methods (default: ["us", "fi"])
  - Simple string: `"us"`, `"fi"`, `"de"` - Basic keyboard layout
  - Attribute set: `{ layout = "cn"; ime = "pinyin"; }` - Layout with input method engine
  - Supported IME: `"pinyin"` (Chinese), `"mozc"` (Japanese), `"hangul"` (Korean), `"unicode"` (Unicode picker)
- `autoActivateIME` - Auto-activate IME when switching to layout with IME (default: true)
- `imeTriggerKey` - Keys to manually toggle IME on/off (default: ["Super+I"])
- `options` - XKB options (default: ["grp:win_space_toggle"] for Super+Space switching)
- `variant` - DEPRECATED: Use variant in layouts instead

**Quick Examples:**
```nix
# English + Finnish + Chinese with Pinyin
marchyo.keyboard.layouts = [
  "us"
  "fi"
  { layout = "cn"; ime = "pinyin"; }
];

# US International + Finnish
marchyo.keyboard.layouts = [
  { layout = "us"; variant = "intl"; }
  "fi"
];

# Multiple CJK languages
marchyo.keyboard.layouts = [
  "us"
  { layout = "cn"; ime = "pinyin"; }
  { layout = "jp"; ime = "mozc"; }
  { layout = "kr"; ime = "hangul"; }
];
```

**Switching Behavior:**
- **Super+Space**: Cycle through all keyboard layouts and input methods
- **Super+I**: Manually toggle IME on/off for current layout
- **Auto-activation**: When `autoActivateIME = true` (default), switching to a layout with IME automatically activates it

**Coverage:**
- ✅ Desktop (Hyprland, Wayland) - Full IME support
- ✅ Login screen (greetd) - Basic keyboard layouts only
- ✅ TTY/Console - Basic keyboard layouts only (no IME)
- ✅ Applications (browser, terminal, office) - Full IME support

**Architecture:**
- fcitx5 manages all input for consistent desktop experience
- XKB provides fallback for TTY/console (basic layouts only)
- Wayland text-input-v3 protocol for modern GTK/Qt apps
- Environment variables (XMODIFIERS, QT_IM_MODULE) for compatibility

**DEPRECATED Options** (use `marchyo.keyboard.layouts` instead):
- `marchyo.inputMethod.enable` → Add IME layouts to `marchyo.keyboard.layouts`
- `marchyo.inputMethod.triggerKey` → Use `marchyo.keyboard.imeTriggerKey`
- `marchyo.inputMethod.enableCJK` → Add specific CJK layouts as needed
- `marchyo.keyboard.variant` → Use `{ layout = "us"; variant = "intl"; }` in layouts

### Dependencies
Key external dependencies (from `flake.nix`):
- **nixpkgs** - NixOS package collection (via FlakeHub)
- **nixos-hardware** - Hardware-specific configurations
- **home-manager** - User environment management (via FlakeHub)
- **nix-colors** - Base16 theming system
- **vicinae** - Default application launcher
- **treefmt-nix** - Code formatting (via FlakeHub)
- **determinate** - Determinate Systems tools (via FlakeHub)
- **fh** - FlakeHub CLI (via FlakeHub)

**Optional dependencies** (not in flake.nix, add if needed):
- **disko** - Disk partitioning configurations available in `disko/` directory (btrfs.nix, luks-btrfs.nix, simple-uefi.nix)

### Colorschemes & Theming System

**Theme composition in flake.nix:**
```nix
colorSchemes = nix-colors.colorSchemes // (import ./colorschemes);
```
This merges 200+ nix-colors schemes with Marchyo's custom schemes.

**Custom colorschemes** (defined in `colorschemes/default.nix`):
- `modus-operandi-tinted` - Light theme by Protesilaos Stavrou (from `colorschemes/modus-operandi-tinted.nix`)
- `modus-vivendi-tinted` - Dark theme by Protesilaos Stavrou (from `colorschemes/modus-vivendi-tinted.nix`)

**Theme variant defaults** (from `modules/nixos/options.nix`):
- When `marchyo.theme.scheme = null`, the default scheme is selected based on `marchyo.theme.variant`:
  - `variant = "dark"` → defaults to `modus-vivendi-tinted`
  - `variant = "light"` → defaults to `modus-operandi-tinted`

**Accessing colorschemes:**
- Within flake: `config._module.args.colorSchemes` (NixOS modules) or `extraSpecialArgs.colorSchemes` (Home Manager)
- External use: `flake.lib.marchyo.colorSchemes`

**Theme propagation:**
- NixOS modules: `config._module.args.colorSchemes = nix-colors.colorSchemes // (import ./colorschemes);`
- Home Manager: Passed via `extraSpecialArgs.colorSchemes` in `home-manager.extraSpecialArgs`

## Packages & Additional Outputs

**Custom packages** (in `packages/`):
- `plymouth-marchyo-theme/` - Custom Plymouth boot theme
- `hyprmon/` - Hyprland monitor configuration utility

**Installer configurations** (in `installer/`):
- `iso-graphical.nix` - Live ISO with graphical desktop environment
- `iso-minimal.nix` - Minimal live ISO for installation

**Disko configurations** (in `disko/`):
- `btrfs.nix` - Btrfs filesystem layout
- `luks-btrfs.nix` - LUKS-encrypted Btrfs setup
- `simple-uefi.nix` - Simple UEFI boot configuration

**Test infrastructure** (in `tests/`):
- `lightweight/` - Fast evaluation tests (run via `nix flake check`)
- `nixos/`, `home/`, `integration/` - VM-based tests (run manually)
- See `tests/README.md` for comprehensive testing documentation

## Using Marchyo

### As a NixOS Module
Import Marchyo's NixOS modules and use feature flags:

```nix
{
  inputs.marchyo.url = "github:yourusername/marchyo";

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
            email = "you@example.com";
          };
        }
      ];
      specialArgs = { inherit inputs; };
    };
  };
}
```

### Flake Outputs
- `nixosModules.default` - Main NixOS module (includes home-manager integration, determinate, and Marchyo modules)
- `nixosModules.home-manager` - Re-exported home-manager NixOS module
- `homeModules.default` - Home Manager module (imports all modules from `modules/home/default.nix`)
- `homeModules._1password` - Standalone 1Password Home Manager module
- `lib.marchyo` - Utility library (currently exports `colors` from `lib/colors.nix`)
- `lib.marchyo.colorSchemes` - Custom colorschemes (modus-operandi-tinted, modus-vivendi-tinted)
- `overlays.default` - Nixpkgs overlay (from `overlays/default.nix`)
- `templates.workstation` - Template with desktop + development setup (default template)
- `checks.{system}.*` - Lightweight evaluation tests
- `vmTests.{system}.*` - VM-based integration tests (not included in `checks`)
- `formatter.{system}` - treefmt formatter configuration

## Development Guidelines

### System Support
- **Supported systems**: x86_64-linux only
- System list defined in flake.nix: `systems = [ "x86_64-linux" ];`

### Code Quality
- **Always run `nix fmt` before committing** - Formats all Nix code using treefmt
- **Always run `nix flake check` before committing** - Validates configuration and runs lightweight tests
- Formatting tools configured: nixfmt, deadnix, statix, actionlint, shellcheck, yamlfmt

### Testing Strategy
- **Lightweight tests** (preferred): Add to `tests/lightweight/` - fast evaluation checks
- **VM tests** (when needed): Add to `tests/nixos/`, `tests/home/`, or `tests/integration/` - runtime validation
- See `tests/README.md` for detailed testing guidelines

### Module Development
- **Adding new custom options**: Edit `modules/nixos/options.nix` (single source of truth for all `marchyo.*` options)
- **Adding new modules**:
  1. Create module file in appropriate directory (`modules/nixos/`, `modules/home/`, or `modules/generic/`)
  2. Import it in the corresponding `default.nix` file
  3. Add lightweight evaluation test in `tests/lightweight/`
- **Auto-configuration modules**: See `desktop-config.nix` and `development-config.nix` for examples of feature flag implementations

### Colorscheme Development
- **Adding custom colorschemes**:
  1. Create scheme file in `colorschemes/` directory
  2. Export it in `colorschemes/default.nix`
  3. Schemes are automatically merged with nix-colors schemes in flake.nix

### Common Patterns
- Use `lib.mkDefault` for options that should be overridable by users
- Use `lib.mkIf cfg.*.enable` for conditional module activation
- Feature flags should trigger comprehensive auto-configuration (see desktop-config.nix, development-config.nix)
- Generic modules in `modules/generic/` are shared between NixOS and Home Manager
