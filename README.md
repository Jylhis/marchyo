# Marchyo

A modular NixOS configuration flake providing a curated set of system and home-manager configurations with sensible defaults.

## Features

- **Modular Architecture**: Organized modules for desktop, development, media, and office environments.
- **Feature Flags**: Simple enable flags that configure entire stacks (desktop, development, etc.).
- **Home Manager Integration**: Seamless user environment management.
- **Hardware Support**: Integration with `nixos-hardware` for common devices.
- **Extensive Configuration**: A rich set of custom options for fine-grained control.

## Quick Start

Marchyo is batteries-included: add it as your **only** input and let
`marchyo.lib.mkNixosSystem` / `mkDarwinSystem` select the correct nixpkgs,
home-manager, stylix, overlay and marchyo modules for your system. No separate
`nixpkgs` input is needed.

```nix
{
  inputs.marchyo.url = "github:Jylhis/marchyo";

  outputs = { marchyo, ... }: {
    nixosConfigurations.myhost = marchyo.lib.mkNixosSystem {
      system = "x86_64-linux";
      modules = [
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

    # macOS works the same way. On x86_64-darwin marchyo transparently pins the
    # stable nixos-26.05 set (the last release supporting Intel macOS); other
    # systems ride unstable.
    # darwinConfigurations.mymac = marchyo.lib.mkDarwinSystem {
    #   system = "x86_64-darwin";
    #   modules = [ ./darwin.nix ];
    # };
  };
}
```

You can still wire the modules manually (`marchyo.nixosModules.default` with
your own `nixpkgs.lib.nixosSystem`) if you prefer — but then you are responsible
for picking the right nixpkgs per system. The raw passthrough
`marchyo.inputs.nixpkgs` is always **unstable**; for a system-correct,
overlay-applied package set use `marchyo.legacyPackages.<system>`.

Alternatively, use the provided template to bootstrap a new configuration:
```bash
nix flake init -t github:Jylhis/marchyo#workstation
```

## Configuration

Marchyo is configured through a set of options under the `marchyo.*` namespace.

### Feature Flags

Enable groups of related functionality with feature flags:

- `marchyo.desktop.enable`: Desktop environment (Hyprland, fonts, audio, bluetooth).
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

Customize the theme variant:

```nix
marchyo.theme = {
  enable = true;
  variant = "dark";  # or "light"
};
```

The dark variant uses the Jylhis Roast palette; the light variant uses Jylhis Paper (both derived from the [Jylhis Design System](https://github.com/jylhis/design) `tokens.json`). Set `marchyo.theme.scheme = "<name>"` to use a `base16-schemes` scheme instead.

**For complete documentation of all available options, see the [Marchyo documentation](docs/).**

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
