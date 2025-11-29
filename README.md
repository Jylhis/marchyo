# Marchyo

A modular NixOS configuration flake providing a curated set of system and home-manager configurations with sensible defaults.

## Features

- **Modular Architecture**: Organized modules for desktop, development, media, and office environments
- **Feature Flags**: Simple enable flags that configure entire stacks (desktop, development, etc.)
- **Theming System**: 200+ Base16 color schemes via nix-colors
- **Home Manager Integration**: Seamless user environment management
- **Hardware Support**: Integration with nixos-hardware for common devices

## Quick Start

Add Marchyo to your flake and import the NixOS module:

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
      specialArgs = { inherit inputs; };
    };
  };
}
```

Alternatively, use the template:
```bash
nix flake init -t github:yourusername/marchyo#workstation
```

## Configuration

### Feature Flags

Enable groups of related functionality with feature flags:

- `marchyo.desktop.enable` - Desktop environment (Hyprland, fonts, audio, bluetooth)
- `marchyo.development.enable` - Development tools (git, docker, virtualization)
- `marchyo.media.enable` - Media applications (auto-enabled with desktop)
- `marchyo.office.enable` - Office applications (auto-enabled with desktop)

### User Configuration

Configure users with metadata for git and applications:

```nix
marchyo.users.myuser = {
  fullname = "Your Name";
  email = "your.email@example.com";
};
```

### Theming

Marchyo includes 200+ Base16 color schemes via [nix-colors](https://github.com/Misterio77/nix-colors):

```nix
marchyo.theme.scheme = "dracula";  # or "gruvbox-dark-medium", "catppuccin-mocha", etc.
```

Custom schemes: `modus-vivendi-tinted` (dark), `modus-operandi-tinted` (light)

**For complete option documentation**, see `modules/nixos/options.nix`

## Development

Essential commands:

```bash
nix flake check  # Validate configuration and run tests
nix fmt          # Format Nix code
nix develop      # Enter development shell
```

The flake includes comprehensive tests. Run `nix flake check` for fast evaluation tests, or see `tests/README.md` for VM-based tests.

**For detailed development guidelines**, see `CLAUDE.md`

## Templates

Bootstrap a new configuration:

```bash
nix flake init -t github:yourusername/marchyo#workstation
```

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
