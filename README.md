# Marchyo

A modular NixOS configuration flake providing a curated set of system and home-manager configurations with sensible defaults.

## Features

- **Modular Architecture**: Organized modules for desktop, development, media, and office environments.
- **Feature Flags**: Simple enable flags that configure entire stacks (desktop, development, etc.).
- **Home Manager Integration**: Seamless user environment management.
- **Hardware Support**: Integration with `nixos-hardware` for common devices.
- **Extensive Configuration**: A rich set of custom options for fine-grained control.

## Quick Start

Add Marchyo to your flake and import the NixOS module:

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

Alternatively, use the provided template to bootstrap a new configuration:
```bash
nix flake init -t github:Jylhis/marchyo#workstation
```

## Configuration

Marchyo is configured through a set of options under the `marchyo.*` namespace.

### Feature Flags

Enable groups of related functionality with feature flags:

- `marchyo.desktop.enable`: Desktop environment (Niri, fonts, audio, bluetooth).
- `marchyo.development.enable`: Development tools (git, docker, virtualization).
- `marchyo.media.enable`: Media applications (auto-enabled with desktop).
- `marchyo.office.enable`: Office applications (auto-enabled with desktop).

### User Configuration

Configure users with metadata for git and applications:

```nix
marchyo.users.myuser = {
  fullname = "Your Name";
  email = "your.email@example.com";
};
```

### Theming

Customize the look and feel of your system:

```nix
marchyo.theme.scheme = "dracula";  # or "gruvbox-dark-medium", "catppuccin-mocha", etc.
```

Custom schemes `modus-vivendi-tinted` (dark) and `modus-operandi-tinted` (light) are also available.

**For a complete list of all available options and their documentation, please see [AI_GUIDE.md](AI_GUIDE.md).**

## Development

Essential commands for development and testing:

```bash
nix flake check  # Validate configuration and run all tests
nix fmt          # Format all Nix code in the repository
nix develop      # Enter a development shell with necessary tools
```

## Contributing

Contributions are highly welcome! To ensure a smooth process, please make sure that:
- All Nix files are formatted with `nix fmt` before committing.
- All tests pass by running `nix flake check`.
- Your commit messages follow the [conventional commit format](https://www.conventionalcommits.org/en/v1.0.0/).

## License

This project is not yet licensed. Please choose a license that suits your needs. The MIT license is a good default choice for open-source projects.

## Acknowledgments

- [nixos-hardware](https://github.com/NixOS/nixos-hardware) for hardware configurations.
- [home-manager](https://github.com/nix-community/home-manager) for user environment management.
