# Marchyo

[![CI](https://github.com/Jylhis/marchyo/actions/workflows/ci.yml/badge.svg)](https://github.com/Jylhis/marchyo/actions/workflows/ci.yml)
[![Deploy Site](https://github.com/Jylhis/marchyo/actions/workflows/deploy-site.yml/badge.svg)](https://github.com/Jylhis/marchyo/actions/workflows/deploy-site.yml)
[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/Jylhis/marchyo/badge)](https://flakehub.com/flake/Jylhis/marchyo)
[![Cachix](https://img.shields.io/badge/cachix-marchyo-blue)](https://app.cachix.org/cache/marchyo)

A modular NixOS configuration flake providing a curated set of system and home-manager configurations with sensible defaults.

**[🌐 Website](https://jylhis.github.io/marchyo/)** | **[📚 Documentation](https://jylhis.github.io/marchyo/docs/)** | **[📦 Releases](https://github.com/Jylhis/marchyo/releases)**

## Features

- **Modular Architecture**: Organized modules for desktop, development, media, and office environments
- **Theming System**: Integrated nix-colors for consistent application theming
- **Custom Wrapper**: `mkNixosSystem` function to reduce boilerplate
- **Home Manager Integration**: Seamless user environment management
- **Hardware Support**: Integration with nixos-hardware for common devices

## Quick Start

### Using in Your Flake

Add Marchyo to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:yourusername/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.myhost = marchyo.lib.marchyo.mkNixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        {
          marchyo = {
            desktop.enable = true;
            development.enable = true;
            theme = {
              enable = true;
              scheme = "gruvbox-dark-medium";
            };
            users.myuser = {
              enable = true;
              fullname = "Your Name";
              email = "your.email@example.com";
            };
          };

          users.users.myuser.isNormalUser = true;
        }
      ];
    };
  };
}
```

### Traditional Module Import

If you prefer not to use the wrapper function:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:yourusername/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        marchyo.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

## Configuration Options

### Core Options

#### `marchyo.desktop.enable`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable desktop environment (Hyprland, Wayland, fonts, etc.)

#### `marchyo.development.enable`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable development tools (Docker, buildah, gh, etc.)

#### `marchyo.media.enable`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable media applications (Spotify, MPV, etc.)

#### `marchyo.office.enable`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable office applications (LibreOffice, Papers, etc.)

### User Configuration

#### `marchyo.users.<name>.enable`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable Marchyo configurations for this user

#### `marchyo.users.<name>.fullname`
- **Type**: `string`
- **Description**: User's full name for git and other applications

#### `marchyo.users.<name>.email`
- **Type**: `string`
- **Description**: User's email address for git and other applications

### Theming

#### `marchyo.theme.enable`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable nix-colors theming system

#### `marchyo.theme.scheme`
- **Type**: `null or string or attrs`
- **Default**: `null`
- **Example**: `"dracula"` or `"gruvbox-dark-medium"`
- **Description**: Color scheme to use. Can be a scheme name from nix-colors or a custom attribute set defining base00-base0F colors

Available color schemes include:
- `dracula`
- `gruvbox-dark-medium`
- `nord`
- `tokyo-night`
- `catppuccin`
- And 200+ more from [nix-colors](https://github.com/Misterio77/nix-colors)

### Localization

#### `marchyo.timezone`
- **Type**: `string`
- **Default**: `"Europe/Zurich"`
- **Example**: `"America/New_York"`
- **Description**: System timezone

#### `marchyo.defaultLocale`
- **Type**: `string`
- **Default**: `"en_US.UTF-8"`
- **Example**: `"de_DE.UTF-8"`
- **Description**: System default locale

## Custom Library Functions

### `marchyo.lib.marchyo.mkNixosSystem`

A wrapper around `lib.nixosSystem` that automatically includes marchyo's modules and provides sensible defaults.

**Benefits:**
- Automatically includes `marchyo.nixosModules.default`
- Passes all flake inputs as `specialArgs`
- Reduces boilerplate configuration
- Enforces consistent base configuration

**Parameters:**
- `system` (required): System architecture (e.g., `"x86_64-linux"`)
- `modules` (optional): List of additional NixOS modules
- `extraSpecialArgs` (optional): Additional special arguments to pass to modules

**Example:**

```nix
nixosConfigurations.myhost = marchyo.lib.marchyo.mkNixosSystem {
  system = "x86_64-linux";
  modules = [
    ./hardware-configuration.nix
    { marchyo.desktop.enable = true; }
  ];
  extraSpecialArgs = {
    customArg = "value";
  };
};
```

## Module Organization

```
modules/
├── nixos/          # NixOS system modules
│   ├── boot.nix
│   ├── desktop.nix
│   ├── fonts.nix
│   ├── graphics.nix
│   ├── hyprland.nix
│   └── ...
├── home/           # Home Manager modules
│   ├── hyprland.nix
│   ├── waybar.nix
│   ├── kitty.nix
│   ├── theme.nix
│   └── ...
└── generic/        # Shared modules
    ├── git.nix
    ├── shell.nix
    └── packages.nix
```

## Using Theming

The nix-colors integration allows you to theme your applications consistently. After enabling `marchyo.theme.enable`, colors are available in Home Manager configurations via `config.colorScheme.palette.baseXX`.

Example in your home configuration:

```nix
programs.kitty = {
  enable = true;
  settings = {
    foreground = "#${config.colorScheme.palette.base05}";
    background = "#${config.colorScheme.palette.base00}";
    color0 = "#${config.colorScheme.palette.base00}";
    color1 = "#${config.colorScheme.palette.base08}";
    # ... more colors
  };
};
```

## Development

### Commands

- `nix flake check` - Validate flake configuration
- `nix flake show` - Display flake outputs
- `nix fmt` - Format Nix code
- `nix develop` - Enter development shell

### Testing

The flake includes comprehensive tests in the `tests/` directory:

```bash
nix flake check  # Run all tests
```

## Templates

Marchyo provides starter templates:

```bash
nix flake init -t github:yourusername/marchyo#workstation
```

Available templates:
- `workstation` - Full developer workstation with desktop and development tools

## Contributing

Contributions are welcome! Please ensure:
- All Nix files are formatted with `nix fmt`
- Tests pass with `nix flake check`
- Commit messages follow conventional commit format

## License

[Add your license here]

## Acknowledgments

- [nix-colors](https://github.com/Misterio77/nix-colors) for the theming system
- [nixos-hardware](https://github.com/NixOS/nixos-hardware) for hardware configurations
- [home-manager](https://github.com/nix-community/home-manager) for user environment management
