# Marchyo Helpers Guide

This document provides comprehensive examples of using the Marchyo perSystem helpers.

## Overview

When you enable Marchyo helpers in your flake, you get access to a rich set of utilities in the `perSystem` context via the `marchyo` attribute. This includes:

- **Custom Packages**: Pre-packaged Marchyo software
- **Builders**: Functions to build VMs, ISOs, and system configurations
- **Color Schemes**: Access to nix-colors and custom Marchyo color schemes
- **Development Shells**: Pre-configured development environments
- **Apps**: Useful CLI utilities for managing your systems

## Enabling Helpers

In your flake:

```nix
{
  inputs = {
    marchyo.url = "github:your-org/marchyo";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        inputs.marchyo.flakeModules.default
      ];

      # Configure Marchyo
      flake.marchyo = {
        helpers.enable = true;  # Enable helpers (enabled by default)
        systems = {
          # Your system configurations will be auto-generated
        };
      };
    };
}
```

## Custom Packages

Access Marchyo's custom packages in your perSystem:

```nix
perSystem = { marchyo, pkgs, ... }: {
  # Expose Plymouth theme as a package
  packages.plymouth = marchyo.packages.plymouth-marchyo-theme;

  # Expose Hyprmon monitor configuration tool
  packages.hyprmon = marchyo.packages.hyprmon;

  # Use in your system configuration
  environment.systemPackages = [
    marchyo.packages.hyprmon
  ];
};
```

## Builders

Build different artifacts from your NixOS configurations:

### VM Builder

```nix
perSystem = { marchyo, ... }: {
  packages = {
    # Build a VM for testing
    workstation-vm = marchyo.builders.vm "workstation";

    # Build a VM with disko disk configuration
    workstation-disko-vm = marchyo.builders.vmWithDisko "workstation";

    # Build the full system toplevel
    workstation-system = marchyo.builders.toplevel "workstation";
  };
};
```

Then build and run:

```bash
# Build VM
nix build .#workstation-vm

# Run the VM
./result/bin/run-nixos-vm
```

### ISO Builder

For systems configured with ISO profiles:

```nix
perSystem = { marchyo, ... }: {
  packages = {
    # Build an ISO installer
    installer-iso = marchyo.builders.iso "installer";
  };
};
```

```bash
# Build ISO
nix build .#installer-iso

# Write to USB
dd if=./result/iso/*.iso of=/dev/sdX bs=4M status=progress
```

## Color Schemes

Access all nix-colors schemes plus custom Marchyo schemes:

```nix
perSystem = { marchyo, pkgs, ... }: {
  # Generate a package with color scheme info
  packages.my-colors = pkgs.writeTextFile {
    name = "colors.txt";
    text = ''
      # Using Dracula color scheme
      Background: ${marchyo.colorSchemes.dracula.palette.base00}
      Foreground: ${marchyo.colorSchemes.dracula.palette.base05}

      # Using custom Marchyo scheme
      Primary: ${marchyo.colorSchemes.modus-vivendi-tinted.palette.base0D}
    '';
  };
};
```

List all available color schemes:

```bash
nix run .#list-colorschemes
```

## Development Shells

Use the pre-configured Marchyo development shell:

```nix
perSystem = { marchyo, pkgs, ... }: {
  # Use the default Marchyo dev shell
  devShells.default = marchyo.devShells.default;

  # Or extend it with additional tools
  devShells.extended = pkgs.mkShell {
    inputsFrom = [ marchyo.devShells.default ];
    buildInputs = with pkgs; [
      # Add your custom tools
      terraform
      ansible
    ];
  };
};
```

Enter the development shell:

```bash
nix develop
```

The shell includes:
- Nix tools (nix, nixfmt-rfc-style, nil, nix-tree, nix-diff, nvd)
- Git tools (git, gh)
- Formatting tools (treefmt, shellcheck, actionlint, deadnix, statix, yamlfmt)
- Utilities (jq, ripgrep, fd)

## Utility Apps

Marchyo provides several useful CLI apps:

### Show Systems

Display all configured systems:

```nix
perSystem = { marchyo, ... }: {
  # Expose the app
  apps.show = marchyo.apps.show-systems;
};
```

```bash
nix run .#show
```

### Build VM Script

Interactive script to build and run VMs:

```nix
perSystem = { marchyo, ... }: {
  apps.vm = marchyo.apps.build-vm;
};
```

```bash
nix run .#vm workstation
```

### List Color Schemes

Browse available color schemes:

```nix
perSystem = { marchyo, ... }: {
  apps.colors = marchyo.apps.list-colorschemes;
};
```

```bash
nix run .#colors
```

## Complete Example

Here's a complete flake using all helper features:

```nix
{
  description = "My Workstation";

  inputs = {
    marchyo.url = "github:your-org/marchyo";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        inputs.marchyo.flakeModules.default
      ];

      flake.marchyo = {
        helpers.enable = true;
        systems.workstation = {
          system = "x86_64-linux";
          config = ./configuration.nix;
        };
      };

      perSystem = { marchyo, pkgs, ... }: {
        # Expose custom packages
        packages = {
          inherit (marchyo.packages) plymouth-marchyo-theme hyprmon;

          # Build artifacts
          vm = marchyo.builders.vm "workstation";
          system = marchyo.builders.toplevel "workstation";

          # Custom package using color schemes
          my-theme = pkgs.writeTextFile {
            name = "my-theme.json";
            text = builtins.toJSON {
              colors = marchyo.colorSchemes.dracula.palette;
            };
          };
        };

        # Development shell
        devShells.default = marchyo.devShells.default;

        # Useful apps
        apps = {
          inherit (marchyo.apps) show-systems build-vm list-colorschemes;

          # Custom app using marchyo lib
          deploy = {
            type = "app";
            program = let
              script = pkgs.writeShellScriptBin "deploy" ''
                echo "Deploying workstation..."
                nix build .#workstation
                # Your deployment logic here
              '';
            in "${script}/bin/deploy";
          };
        };
      };
    };
}
```

## Library Access

Access Marchyo's extended library functions:

```nix
perSystem = { marchyo, ... }: {
  # Use marchyo.lib for utility functions
  packages = marchyo.lib.mapListToAttrs
    [ "foo" "bar" "baz" ]
    (name: pkgs.writeText name "content");
};
```

## Input System Access

Access system-specific inputs:

```nix
perSystem = { marchyo, ... }: {
  # marchyo.inputs' provides system-specific input access
  packages.my-pkg = marchyo.inputs'.nixpkgs.legacyPackages.hello;
};
```

## Legacy Helpers

For backward compatibility, these helpers are still available:

```nix
perSystem = { marchyo, ... }: {
  # DEPRECATED: Use marchyo.builders.vm instead
  packages.vm-old = marchyo.mkTestVm "workstation";

  # Build all systems at once (lazy evaluation)
  packages = marchyo.buildAllSystems;

  # Get system config
  myConfig = marchyo.getSystemConfig "workstation";

  # Check if system exists
  hasWorkstation = marchyo.hasSystem "workstation";
};
```

## Error Handling

Builders provide clear error messages:

```nix
# If system doesn't exist:
marchyo.builders.vm "nonexistent"
# Error: System 'nonexistent' not found in nixosConfigurations.
# Available systems: workstation, server

# If trying to build ISO without ISO profile:
marchyo.builders.iso "workstation"
# Error: System 'workstation' does not have ISO image configured.
# You need to import an ISO profile...

# If trying to build VM with disko without disko configured:
marchyo.builders.vmWithDisko "workstation"
# Error: System 'workstation' does not have disko configured.
# Make sure disko is imported...
```

## Best Practices

1. **Enable helpers by default**: They're lazy-evaluated, so there's no cost if not used
2. **Use builders for testing**: The VM builders are perfect for testing configurations
3. **Expose useful packages**: Make frequently-used packages available via perSystem
4. **Extend dev shells**: Build on top of the default dev shell for project-specific needs
5. **Use color schemes consistently**: Reference marchyo.colorSchemes for theming

## Tips

- All builders are lazy - they only evaluate when actually built
- Apps can be combined with your own custom scripts
- The dev shell automatically shows configured systems on entry
- Use `nix flake show` to see all available outputs
- Color schemes follow the base16 format from nix-colors

## Troubleshooting

If helpers aren't available:
1. Ensure `flake.marchyo.helpers.enable = true` (it's true by default)
2. Check that you've imported `inputs.marchyo.flakeModules.default`
3. Verify your systems are configured in `flake.marchyo.systems`

If builders fail:
1. Check the error message for specific issues
2. Ensure the system name matches your configuration
3. For ISO/disko builders, verify required modules are imported
4. Use `nix flake check` to validate your configuration
