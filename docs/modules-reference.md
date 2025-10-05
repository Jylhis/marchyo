# Modules Reference

Complete reference documentation for all Marchyo modules, organized by category.

## Table of Contents

- [Overview](#overview)
- [NixOS Modules](#nixos-modules)
  - [System Foundation](#system-foundation)
  - [Desktop Environment](#desktop-environment)
  - [Hardware & Performance](#hardware--performance)
  - [Applications & Services](#applications--services)
  - [Security & Utilities](#security--utilities)
- [Home Manager Modules](#home-manager-modules)
  - [Desktop Applications](#desktop-applications)
  - [Terminal & Shell](#terminal--shell)
  - [Development Tools](#development-tools)
- [Generic Modules](#generic-modules)

## Overview

Marchyo's modular architecture separates configuration into logical units:

- **NixOS Modules** (`modules/nixos/`) - System-level configuration
- **Home Manager Modules** (`modules/home/`) - User-level configuration
- **Generic Modules** (`modules/generic/`) - Shared configuration used by both

Most modules are automatically enabled based on feature flags (`marchyo.desktop.enable`, etc.), but can be individually configured or overridden.

---

## NixOS Modules

System-level modules that configure NixOS services, packages, and system settings.

### System Foundation

Core system configuration that provides the base functionality.

#### boot.nix

Boot loader and kernel configuration.

**Purpose:** Configures systemd-boot UEFI bootloader with generation management.

**Key Features:**
- Systemd-boot as bootloader
- Console font and keymap configuration
- Silent boot with plymouth
- Timeout configuration

**Enabled:** Always (required for system boot)

**Options:**
```nix
boot = {
  loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
};
```

#### nix-settings.nix

Nix daemon and build configuration.

**Purpose:** Configures Nix package manager with modern settings and optimizations.

**Key Features:**
- Auto-optimization of Nix store
- Flakes and nix-command enabled
- Garbage collection configuration
- Binary cache settings
- Build sandboxing

**Enabled:** Always

**Example Configuration:**
```nix
nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  auto-optimise-store = true;
};
```

#### system.nix

General system services and configuration.

**Purpose:** Base system services like NetworkManager, sudo, polkit.

**Key Features:**
- NetworkManager for network management
- Sudo configuration
- Polkit for privilege escalation
- Basic system utilities

**Enabled:** Always

#### locale.nix

Language and localization settings.

**Purpose:** Configures system locale based on `marchyo.defaultLocale` and `marchyo.timezone`.

**Key Features:**
- Default locale (language/encoding)
- Extra locales for multi-language support
- Timezone configuration

**Enabled:** Always

**Options:**
```nix
marchyo = {
  defaultLocale = "en_US.UTF-8";  # System language
  timezone = "Europe/Zurich";      # System timezone
};
```

**What It Sets:**
- `i18n.defaultLocale`
- `i18n.extraLocaleSettings`
- `time.timeZone`

#### options.nix

Defines all `marchyo.*` configuration options.

**Purpose:** Central definition of Marchyo's custom options namespace.

**Defines:**
- `marchyo.users.*` - User configuration submodules
- `marchyo.desktop.enable` - Desktop environment flag
- `marchyo.development.enable` - Development tools flag
- `marchyo.media.enable` - Media applications flag
- `marchyo.office.enable` - Office applications flag
- `marchyo.timezone` - System timezone
- `marchyo.defaultLocale` - System locale

See [configuration.md](configuration.md) for detailed option documentation.

#### packages.nix

System-wide package installation based on feature flags.

**Purpose:** Installs packages conditionally based on `marchyo.*` flags.

**Always Installed:**
- Shell tools: `fzf`, `ripgrep`, `eza`, `fd`
- TUI tools: `btop`, `fastfetch`, `bluetui`, `sysz`, `lazyjournal`, `impala`
- System programs: `television`, `zoxide`, `lazygit`

**With `marchyo.desktop.enable`:**
- `signal-desktop` - Messaging
- `brave` - Browser
- `localsend` - File sharing
- `file-roller` - Archive manager
- `nautilus` - File explorer

**With `marchyo.media.enable`:**
- `mpv` - Video player
- `pinta` - Image editor

**With `marchyo.office.enable`:**
- `libreoffice` - Office suite
- `papers` - Document viewer
- `xournalpp` - PDF annotation
- `obsidian` - Note-taking

**With `marchyo.development.enable`:**
- `docker-compose` - Container orchestration
- `buildah` - Container building
- `skopeo` - Container registry tools
- `lazydocker` - Docker TUI
- `gh` - GitHub CLI

### Desktop Environment

Modules that configure the Hyprland desktop and Wayland ecosystem.

#### hyprland.nix

Hyprland window manager configuration.

**Purpose:** Enables and configures Hyprland dynamic tiling Wayland compositor.

**Key Features:**
- Hyprland package installation
- XWayland support
- Session management
- Portal configuration (xdg-desktop-portal-hyprland)

**Enabled When:** `marchyo.desktop.enable = true`

**Provides:**
- Hyprland compositor
- Wayland protocols
- Screen sharing capabilities
- XWayland for legacy X11 apps

**Example:**
```nix
marchyo.desktop.enable = true;

# Hyprland is automatically configured
# User-specific config in modules/home/hyprland.nix
```

#### wayland.nix

Wayland support and related tools.

**Purpose:** Enables Wayland-specific system services and utilities.

**Key Features:**
- XDG desktop portal
- Screenshot tools (grim, slurp)
- Clipboard management (wl-clipboard)
- Wayland-native tools

**Enabled When:** `marchyo.desktop.enable = true`

**Installed Packages:**
- `grim` - Screenshot utility
- `slurp` - Screen selection tool
- `wl-clipboard` - Clipboard utilities
- `swaynotificationcenter` - Notification daemon

#### graphics.nix

Graphics acceleration and OpenGL support.

**Purpose:** Enables hardware-accelerated graphics.

**Key Features:**
- OpenGL support
- Vulkan drivers
- 32-bit graphics (for gaming)

**Enabled When:** `marchyo.desktop.enable = true`

**Configuration:**
```nix
hardware.graphics = {
  enable = true;
  enable32Bit = true;
};
```

#### fonts.nix

System font configuration.

**Purpose:** Installs and configures system fonts.

**Enabled When:** `marchyo.desktop.enable = true`

**Installed Fonts:**
- Nerd Fonts (JetBrainsMono, FiraCode, etc.)
- Inter
- Liberation Serif
- Noto fonts (including CJK and emoji)

#### audio.nix

Audio system configuration with PipeWire.

**Purpose:** Configures modern audio stack.

**Key Features:**
- PipeWire for audio/video processing
- ALSA compatibility
- PulseAudio compatibility
- JACK support
- Low-latency audio

**Enabled When:** `marchyo.desktop.enable = true`

**Services:**
```nix
services.pipewire = {
  enable = true;
  alsa.enable = true;
  pulse.enable = true;
  jack.enable = true;
};
```

#### hyprlock.nix

Screen locking system module.

**Purpose:** Enables Hyprlock for screen locking.

**Enabled When:** `marchyo.desktop.enable = true`

**Provides:**
- PAM configuration for hyprlock
- Security integration

**Note:** User-specific lock screen config is in `modules/home/hyprlock.nix`.

### Hardware & Performance

Modules for hardware support and performance tuning.

#### hardware.nix

General hardware enablement.

**Purpose:** Enables common hardware support.

**Key Features:**
- Bluetooth support
- Printer support via CUPS
- Scanner support via SANE

**Enabled When:** `marchyo.desktop.enable = true`

**Services:**
```nix
hardware.bluetooth.enable = true;
services.blueman.enable = true;
```

#### performance.nix

System performance tuning.

**Purpose:** Optimizes system for better performance.

**Key Features:**
- Kernel parameters for performance
- I/O scheduler optimization
- CPU governor settings

**Enabled:** Always

**Example Tuning:**
- Swappiness reduction
- Dirty page writeback tuning
- Transparent hugepages

#### powersave.nix

Power saving configuration (primarily for laptops).

**Purpose:** Reduces power consumption.

**Key Features:**
- TLP for laptop power management
- Auto-CPU-freq for dynamic frequency scaling
- USB autosuspend

**Enabled:** Auto-detected for laptops

#### printing.nix

Printer support via CUPS.

**Purpose:** Enables printing services.

**Enabled When:** `marchyo.desktop.enable = true`

**Features:**
- CUPS printing system
- Network printer discovery (Avahi)
- Common printer drivers

### Applications & Services

Application-specific modules and services.

#### containers.nix

Container runtime support (Docker/Podman).

**Purpose:** Enables Docker daemon for container management.

**Enabled When:** `marchyo.development.enable = true`

**Services:**
```nix
virtualisation.docker = {
  enable = true;
  enableOnBoot = true;
};
```

**Note:** Users must be added to `docker` group manually:
```nix
users.users.username.extraGroups = [ "docker" ];
```

#### media.nix

Media-specific services and configuration.

**Purpose:** Configures media playback environment.

**Enabled When:** `marchyo.media.enable = true`

**Features:**
- GStreamer plugins
- Media codec support
- Thumbnail generation

#### network.nix

Network configuration and services.

**Purpose:** Network management with NetworkManager.

**Key Features:**
- NetworkManager for network connections
- WiFi support
- VPN support
- Firewall configuration

**Enabled:** Always

**Services:**
```nix
networking.networkmanager.enable = true;
networking.firewall.enable = true;
```

#### plymouth.nix

Boot splash screen.

**Purpose:** Provides graphical boot experience.

**Enabled When:** `marchyo.desktop.enable = true`

**Features:**
- Marchyo-themed Plymouth splash
- Silent boot configuration
- Smooth transitions

### Security & Utilities

Security hardening and system utilities.

#### security.nix

Security hardening and policies.

**Purpose:** Hardens system security.

**Key Features:**
- Sudo configuration with security flags
- Polkit rules
- Firewall defaults
- Kernel hardening parameters

**Enabled:** Always

**Example Hardening:**
- `kernel.unprivileged_bpf_disabled = 1`
- `kernel.kptr_restrict = 2`
- Sudo timeout configuration

#### _1password.nix

1Password integration.

**Purpose:** Enables 1Password desktop app and SSH agent.

**Enabled:** Manual (opt-in)

**Features:**
- 1Password desktop application
- 1Password SSH agent
- Browser integration

**Usage:**
```nix
# Import in your configuration:
imports = [ marchyo.nixosModules._1password ];
```

#### help.nix

Man pages and documentation.

**Purpose:** Enables system documentation.

**Key Features:**
- Man pages for all packages
- Info pages
- Documentation tools

**Enabled:** Always

#### update-diff.nix

System update comparison tools.

**Purpose:** Provides tools to preview system changes.

**Key Features:**
- `nvd` - Nix Version Diff
- Automatic diff on rebuild

**Enabled:** Always

**Usage:**
```bash
nvd diff /run/current-system /run/booted-system
```

---

## Home Manager Modules

User-level modules that configure applications and user environment.

### Desktop Applications

Applications for the Hyprland desktop environment.

#### hyprland.nix

Hyprland user configuration.

**Purpose:** Configures Hyprland window manager settings, keybindings, and appearance.

**Key Features:**
- Comprehensive keybinding configuration
- Window rules for applications
- Workspace management
- Animations and effects
- Auto-start applications
- Monitor configuration

**Enabled When:** `marchyo.desktop.enable = true`

**Includes:**
- Super key based keybindings
- Vim-like navigation (H/J/K/L)
- Workspace switching (1-9)
- Window manipulation (move, resize, float, fullscreen)
- Application launchers (Wofi, terminal, browser)
- Screenshot keybindings
- Volume/brightness controls

**Example Keybindings:**
- `Super + Return` - Terminal
- `Super + Q` - Close window
- `Super + R` - App launcher
- `Super + H/J/K/L` - Move focus
- `Super + 1-9` - Switch workspace

#### waybar.nix

Status bar configuration.

**Purpose:** Configures Waybar status bar for Hyprland.

**Key Features:**
- Workspace indicators
- System tray
- Clock and date
- CPU/Memory/Disk usage
- Network status
- Audio volume
- Battery (on laptops)
- Custom modules

**Enabled When:** `marchyo.desktop.enable = true`

**Modules:**
- Left: Workspaces, window title
- Center: Clock
- Right: System stats, network, audio, battery, tray

#### wofi.nix

Application launcher.

**Purpose:** Configures Wofi application launcher (dmenu replacement).

**Key Features:**
- Fuzzy search
- Application icons
- Recent applications
- Custom styling

**Enabled When:** `marchyo.desktop.enable = true`

**Launch:** `Super + R`

#### mako.nix

Notification daemon.

**Purpose:** Configures Mako notification system.

**Key Features:**
- Desktop notifications
- Notification history
- Grouped notifications
- Custom styling with theme

**Enabled When:** `marchyo.desktop.enable = true`

#### hyprpaper.nix

Wallpaper manager.

**Purpose:** Sets desktop wallpaper.

**Enabled When:** `marchyo.desktop.enable = true`

**Features:**
- Multi-monitor wallpaper support
- Wallpaper preloading
- Dynamic wallpaper changes

#### hyprlock.nix

Screen lock configuration.

**Purpose:** Configures Hyprlock screen locker.

**Key Features:**
- Lock screen appearance
- Timeout settings
- Authentication configuration

**Enabled When:** `marchyo.desktop.enable = true`

**Lock:** `Super + L` or automatic after idle

#### hypridle.nix

Idle management.

**Purpose:** Configures automatic actions on idle.

**Key Features:**
- Screen dimming after 5 minutes
- Screen lock after 10 minutes
- Screen off after 15 minutes

**Enabled When:** `marchyo.desktop.enable = true`

#### theme.nix

GTK/Qt theming.

**Purpose:** Provides consistent theme across applications.

**Key Features:**
- GTK 2/3/4 theme configuration
- Qt theme integration
- Icon theme
- Cursor theme
- Color scheme from nix-colors

**Enabled When:** `marchyo.desktop.enable = true`

### Terminal & Shell

Terminal emulators and shell configuration.

#### kitty.nix

Kitty terminal emulator.

**Purpose:** Configures Kitty as the primary terminal.

**Key Features:**
- GPU-accelerated rendering
- Ligature support
- Tab management
- Custom keybindings
- Theme integration

**Enabled When:** User has Marchyo configuration

**Default Shell:** Fish

**Launch:** `Super + Return`

#### ghostty.nix

Alternative terminal emulator (Ghostty).

**Purpose:** Provides Ghostty terminal as an alternative.

**Enabled:** Manual (opt-in via Home Manager)

**Features:**
- Lightweight
- Modern features
- Theme support

#### shell.nix

Shell configuration and aliases.

**Purpose:** Configures shell environment (Fish primarily).

**Key Features:**
- Fish shell enabled
- Starship prompt
- Common aliases
- Environment variables

**Enabled When:** User has Marchyo configuration

**Aliases:**
- `ls` → `eza -lh --group-directories-first --icons=auto`
- `cat` → `bat`
- `find` → `fd`
- Git shortcuts: `g`, `gs`, `ga`, `gcm`, etc.

#### direnv.nix

Directory-based environment management.

**Purpose:** Automatically loads project-specific environments.

**Key Features:**
- `nix-direnv` integration for faster evaluation
- Shell integration (Bash, Fish, Zsh)
- Automatic environment activation

**Enabled When:** User has Marchyo configuration

**Usage:** Create `.envrc` in project:
```bash
use flake
```

### Development Tools

Tools and applications for development.

#### git.nix

Git configuration.

**Purpose:** Configures Git with user information from `marchyo.users.<name>`.

**Key Features:**
- User name and email from Marchyo config
- Default branch configuration
- Merge strategy
- Common aliases

**Enabled When:** User has Marchyo configuration

**Auto-configured:**
```nix
programs.git = {
  userName = config.marchyo.users.<name>.fullname;
  userEmail = config.marchyo.users.<name>.email;
};
```

#### btop.nix

System resource monitor.

**Purpose:** Configures btop++ resource monitor.

**Key Features:**
- CPU/Memory/Disk/Network monitoring
- Process management
- Theme integration
- Vim keybindings

**Enabled When:** User has Marchyo configuration

**Launch:** `btop` in terminal

#### fastfetch.nix

System information display.

**Purpose:** Configures fastfetch for system info.

**Key Features:**
- Fast system information
- ASCII art logo
- Customizable modules

**Enabled When:** User has Marchyo configuration

**Launch:** `fastfetch` in terminal

### Miscellaneous

Other user-specific configurations.

#### packages.nix

User-specific package installation.

**Purpose:** Installs user-level packages based on configuration.

**Installed Packages:**
- Terminal tools (as defined in parent module)
- User-requested packages

**Enabled When:** User has Marchyo configuration

#### locale.nix

User locale settings.

**Purpose:** Inherits system locale settings for user environment.

**Enabled When:** User has Marchyo configuration

#### _1password.nix

1Password user configuration.

**Purpose:** Configures 1Password for user.

**Enabled:** Manual (opt-in)

**Features:**
- SSH agent integration
- Git signing with 1Password
- Browser integration

#### xournalpp.nix

PDF annotation tool configuration.

**Purpose:** Configures Xournalpp settings.

**Enabled When:** `marchyo.office.enable = true`

---

## Generic Modules

Modules shared between NixOS and Home Manager.

### fontconfig.nix

Font configuration shared across system and users.

**Purpose:** Provides consistent font configuration.

**Key Features:**
- Default font families
- Font rendering settings
- Antialiasing configuration

**Used By:** Both system and Home Manager

### git.nix

Shared Git configuration.

**Purpose:** Base Git settings used by both system and users.

**Key Features:**
- Common Git aliases
- Default configuration
- Merge strategies

**Used By:** Both system and Home Manager

### shell.nix

Shared shell configuration.

**Purpose:** Base shell settings used across the system.

**Key Features:**
- Common aliases
- Shell functions
- Environment setup

**Used By:** Both system and Home Manager

---

## Module Dependency Graph

Understanding how modules depend on each other:

```
options.nix (defines marchyo.* namespace)
    ↓
packages.nix (reads marchyo.*.enable flags)
    ↓
Feature-specific modules (hyprland, containers, etc.)
    ↓
Generic modules (shell, git, fonts)
    ↓
Home Manager modules (inherit from generic + add user-specific)
```

## Module Development

Creating new modules following Marchyo conventions:

```nix
# modules/nixos/mymodule.nix
{ lib, config, pkgs, ... }:
let
  cfg = config.marchyo;  # or config.marchyo.myfeature
in
{
  config = lib.mkIf cfg.somefeature.enable {
    # Module configuration here

    environment.systemPackages = with pkgs; [
      # Packages for this module
    ];

    services.myservice = {
      enable = true;
      # Service configuration
    };
  };
}
```

**Best Practices:**
1. Use `lib.mkIf` to conditionally enable
2. Reference `marchyo.*` options for feature flags
3. Document the module purpose in comments
4. Group related configuration together
5. Use appropriate default values

## Next Steps

- [Configuration Guide](configuration.md) - How to use these modules
- [Troubleshooting](troubleshooting.md) - Common module issues
- [Examples](../examples/) - Real-world module usage

## Getting Help

- Check module source code in `modules/` directory
- Review existing configurations in `examples/`
- Open an issue on GitHub for module questions
