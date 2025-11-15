# Architecture

Understanding Marchyo's project structure and design.

## Project Structure

```
marchyo/
├── flake.nix                 # Main flake definition
├── modules/                  # Configuration modules
│   ├── nixos/               # System-level modules (27 modules)
│   ├── home/                # User-level modules (29 modules)
│   └── generic/             # Shared modules (4 modules)
├── colorschemes/            # Custom color schemes
├── lib/                     # Utility functions
├── packages/                # Custom packages
├── overlays/                # Nixpkgs overlays
├── templates/               # Project templates
├── installer/               # Installation ISOs
├── disko/                   # Disk partitioning configs
├── tests/                   # Test infrastructure
├── docs/                    # Documentation (this site)
└── assets/                  # Static resources
```

## Module Organization

### NixOS Modules (`modules/nixos/`)

System-level configuration organized by function:

**Core System:**
- `options.nix` - Defines `marchyo.*` namespace
- `nix-settings.nix` - Nix configuration, caches
- `boot.nix` - Bootloader and login manager
- `system.nix` - System-level settings
- `network.nix` - Networking configuration

**Desktop Environment:**
- `desktop-config.nix` - Auto-configuration when desktop enabled
- `hyprland.nix` - Hyprland window manager
- `fonts.nix` - Font configuration
- `graphics.nix` - Graphics drivers
- `wayland.nix` - Wayland support
- `audio.nix` - PipeWire audio
- `plymouth.nix` - Boot splash screen

**Development:**
- `development-config.nix` - Auto-configuration for dev tools
- `containers.nix` - Docker/Podman
- Package integrations in `packages.nix`

**Applications:**
- `media.nix` - Media applications
- `packages.nix` - System packages organized by category

### Home Manager Modules (`modules/home/`)

User environment configuration:

**Desktop:**
- `hyprland.nix` - User Hyprland config (566 lines!)
- `waybar.nix` - Status bar
- `mako.nix` - Notifications
- `vicinae.nix` - Application launcher
- `theme.nix` - Color scheme integration

**Terminal:**
- `kitty.nix` - Terminal emulator
- `shell.nix` - Shell configuration
- `starship.nix` - Prompt customization

**Development:**
- `git.nix` - Git configuration (pulls from NixOS user config)
- `lazygit.nix` - Git TUI

**System Tools:**
- `btop.nix` - System monitor
- `fastfetch.nix` - System info
- `fzf.nix` - Fuzzy finder
- `bat.nix` - Enhanced cat

### Generic Modules (`modules/generic/`)

Shared between NixOS and Home Manager:

- `git.nix` - Git base configuration
- `shell.nix` - Shell defaults
- `fontconfig.nix` - Font configuration
- `packages.nix` - Shared packages

## Data Flow

### Configuration Evaluation

```
flake.nix
  ↓
nixosModules.default
  ↓
modules/nixos/default.nix (imports all NixOS modules)
  ↓
Individual modules read marchyo.* options
  ↓
Generate system configuration
  ↓
home-manager integration
  ↓
modules/home/default.nix (imports all Home modules)
  ↓
Home modules access osConfig.marchyo.* for system settings
  ↓
Final system + user configuration
```

### Theme Propagation

```
marchyo.theme.scheme
  ↓
nix-colors evaluation
  ↓
colorSchemes merged (nix-colors + custom)
  ↓
config.colorScheme.palette available in Home Manager
  ↓
Each application reads palette:
  - kitty colors
  - waybar CSS variables
  - hyprland border colors
  - mako notification colors
  - vicinae theme.toml generation
  - starship prompt colors
```

### User Configuration Flow

```
marchyo.users.alice.{fullname, email}
  ↓
Stored in NixOS config
  ↓
Home Manager git module
  ↓
osConfig.marchyo.users.alice
  ↓
programs.git.userName = fullname
programs.git.userEmail = email
```

## Dependency Graph

```
flake inputs:
  nixpkgs ────────────┐
  home-manager ───────┼──→ marchyo.nixosModules.default
  nix-colors ─────────┤
  vicinae ────────────┤
  determinate ────────┘

  nix-mdbook ─────────────→ docs build

  nixos-hardware (optional)
  treefmt-nix (formatter)
```

## Build Process

### System Build

```bash
nix build .#nixosConfigurations.hostname
```

1. Evaluate flake.nix
2. Import nixosModules.default
3. Evaluate all NixOS modules with user config
4. Build system derivation
5. Include home-manager configurations
6. Generate bootloader entries

### Documentation Build

```bash
nix build .#docs
```

1. Evaluate modules to extract options
2. Generate markdown with `nixosOptionsDoc`
3. Prepare source directory (hand-written + generated)
4. Build with mdBook via nix-mdbook
5. Output static HTML site

## Feature Flag System

Feature flags use conditional imports:

```nix
# In desktop-config.nix
config = lib.mkIf cfg.desktop.enable {
  # Enable services
  services.pipewire.enable = true;

  # Install packages
  environment.systemPackages = with pkgs; [ ... ];

  # Auto-enable related features
  marchyo.office.enable = lib.mkDefault true;
  marchyo.media.enable = lib.mkDefault true;
};
```

This pattern provides:
- **Single source of truth** for related functionality
- **Automatic dependency management**
- **Override capability** (`mkDefault` allows user override)
- **Clean abstraction** over complex configurations

## Integration Points

### NixOS ↔ Home Manager

Home Manager modules access NixOS configuration:

```nix
# In home module
config.programs.git = {
  userName = osConfig.marchyo.users.${config.home.username}.fullname;
  userEmail = osConfig.marchyo.users.${config.home.username}.email;
};
```

### System ↔ User Theming

Color schemes flow from system to user applications:

```nix
# System level (configuration.nix)
marchyo.theme.scheme = "dracula";

# Automatically available in Home Manager
config.colorScheme.palette.base0D  # Blue from dracula
```

## Design Principles

1. **Modularity**: Each module has single responsibility
2. **Composability**: Modules work together through well-defined interfaces
3. **Sensible Defaults**: Feature flags enable curated configurations
4. **Override Capability**: Users can customize everything
5. **Type Safety**: NixOS module system ensures correctness
6. **Reproducibility**: Flake locks guarantee exact dependencies

## See Also

- [Module System](module-system.md) - How modules work
- [Theming System](theming-system.md) - Theme integration details
- [Design Decisions](design-decisions.md) - Rationale for choices
