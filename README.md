# Marchyo

A modern, declarative NixOS distribution featuring a polished Hyprland desktop environment, comprehensive system modules, and production-ready configurations.

## Features

### 🎨 Modern Desktop Experience
- **Hyprland** - Dynamic tiling Wayland compositor with smooth animations
- **Polished Ecosystem** - Waybar, Wofi, Mako, Hypridle, Hyprlock pre-configured
- **Dual Terminals** - Kitty and Ghostty with sensible defaults
- **Theme Integration** - Consistent Qt/GTK theming

### 🔧 Developer Productivity
- **Development Tools** - Docker/Podman, GitHub CLI, Buildah
- **Modern CLI Tools** - eza, bat, fd, ripgrep, zoxide, starship
- **Shell Enhancements** - Fish/Bash with history, completions, aliases
- **Git Integration** - Full git setup with LFS support

### 📦 Modular Architecture
- **Feature Flags** - Enable/disable desktop, development, media, office modules
- **User Profiles** - Per-user configuration with email, fullname metadata
- **Clean Separation** - System (NixOS) and user (Home Manager) modules
- **Tested** - Comprehensive VM tests for all configurations

### 🚀 Production Ready
- **Flake-based** - Reproducible builds with pinned dependencies
- **Comprehensive Tests** - NixOS VM tests, Home Manager tests, integration tests
- **CI/CD** - Automated testing, formatting, and binary caching
- **Update Diff** - See what changes before applying updates

## Installation

### From Existing NixOS

Add Marchyo to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        marchyo.nixosModules.default
        marchyo.inputs.home-manager.nixosModules.home-manager
        {
          # Enable Marchyo features
          marchyo = {
            desktop.enable = true;
            development.enable = true;
            users.yourname = {
              enable = true;
              fullname = "Your Name";
              email = "you@example.com";
            };
          };

          # Home Manager integration
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.yourname = {
              imports = [ marchyo.homeModules.default ];
              home.stateVersion = "24.11";
            };
          };
        }
      ];
    };
  };
}
```

Then rebuild your system:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

### Standalone Home Manager

Use Marchyo's Home Manager modules independently:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs = { home-manager, marchyo, ... }: {
    homeConfigurations.yourname = home-manager.lib.homeManagerConfiguration {
      modules = [
        marchyo.homeModules.default
        {
          home = {
            username = "yourname";
            homeDirectory = "/home/yourname";
            stateVersion = "24.11";
          };
        }
      ];
    };
  };
}
```

## Quick Start

### Available Options

```nix
marchyo = {
  # Feature flags
  desktop.enable = true;      # Hyprland + Wayland + Fonts + Graphics
  development.enable = true;  # Docker + GitHub CLI + Dev tools
  media.enable = true;        # Spotify, MPV, media applications
  office.enable = true;       # LibreOffice, Papers, Xournal++

  # System settings
  timezone = "Europe/Zurich";     # Default: Europe/Zurich
  defaultLocale = "en_US.UTF-8";  # Default: en_US.UTF-8

  # User configuration
  users.username = {
    enable = true;
    fullname = "Your Full Name";
    email = "your.email@example.com";
  };
};
```

### Home Manager Modules

Marchyo provides these Home Manager modules:

- **Desktop Environment**: Hyprland, Waybar, Wofi, Mako, Hypridle, Hyprlock
- **Terminals**: Kitty, Ghostty with theming
- **Shell**: Bash/Fish with enhancements, aliases, completions
- **Development**: Git configuration, lazygit
- **CLI Tools**: btop, fastfetch, modern replacements (eza, bat, fd, ripgrep)
- **Productivity**: Xournal++ for note-taking

## Configuration Examples

### Minimal Server

```nix
marchyo = {
  users.admin = {
    enable = true;
    fullname = "Administrator";
    email = "admin@server.local";
  };
  timezone = "UTC";
};
```

### Developer Workstation

```nix
marchyo = {
  desktop.enable = true;
  development.enable = true;
  office.enable = true;

  users.developer = {
    enable = true;
    fullname = "Developer Name";
    email = "dev@company.com";
  };
};
```

### Gaming Desktop

```nix
marchyo = {
  desktop.enable = true;
  media.enable = true;

  users.gamer = {
    enable = true;
    fullname = "Gamer Name";
    email = "gamer@example.com";
  };
};
```

## Module Reference

### NixOS Modules

| Module | Description |
|--------|-------------|
| audio | PipeWire audio setup |
| boot | systemd-boot with greetd login |
| containers | Docker/Podman container runtime |
| fonts | Nerd fonts, Liberation, Inter |
| graphics | Mesa, Vulkan, hardware acceleration |
| hyprland | Hyprland compositor configuration |
| locale | Timezone and locale settings |
| media | Media applications (when enabled) |
| network | NetworkManager configuration |
| packages | System-wide packages based on feature flags |
| plymouth | Custom Marchyo boot theme |
| printing | CUPS printing support |
| security | Polkit configuration |

### Home Manager Modules

| Module | Description |
|--------|-------------|
| btop | Resource monitor configuration |
| fastfetch | System info display |
| git | Git configuration with user details |
| ghostty | Ghostty terminal setup |
| hypridle | Idle management and screen lock |
| hyprland | Hyprland user configuration |
| hyprlock | Screen lock configuration |
| hyprpaper | Wallpaper management |
| kitty | Kitty terminal configuration |
| mako | Notification daemon |
| shell | Bash/Fish with enhancements |
| waybar | Status bar configuration |
| wofi | Application launcher |
| xournalpp | PDF annotation tool |

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

### Quick Commands

```bash
# Validate configuration
nix flake check

# Format code
nix fmt

# Build specific configuration
nix build .#nixosConfigurations.hostname

# Run tests
nix build .#checks.x86_64-linux.nixos-desktop
```

## Project Structure

```
marchyo/
├── flake.nix              # Flake definition
├── modules/
│   ├── nixos/             # NixOS system modules
│   ├── home/              # Home Manager user modules
│   ├── generic/           # Shared modules
│   └── flake/             # Flake-specific modules
├── packages/              # Custom packages
│   ├── hyprmon/           # Hyprland monitor manager
│   └── plymouth-marchyo-theme/
├── tests/                 # VM and integration tests
├── lib/                   # Custom library functions
└── assets/                # Static assets (wallpapers, CSS)
```

## Binary Cache

Marchyo uses Cachix for binary caching:

```nix
nix.settings = {
  substituters = [ "https://marchyo.cachix.org" ];
  trusted-public-keys = [ "marchyo.cachix.org-1:..." ];
};
```

## Support & Community

- **Issues**: [GitHub Issues](https://github.com/Jylhis/marchyo/issues)
- **Documentation**: [docs/](docs/)
- **Examples**: [examples/](examples/)

## License

This project follows the licensing of included components. See individual modules for specific licenses.

## Acknowledgments

Built with:
- [NixOS](https://nixos.org/) - Declarative Linux distribution
- [Home Manager](https://github.com/nix-community/home-manager) - User environment management
- [Hyprland](https://hyprland.org/) - Dynamic tiling Wayland compositor
- [flake-parts](https://flake.parts/) - Flake framework
