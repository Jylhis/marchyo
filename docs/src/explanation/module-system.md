# Module System

Understanding NixOS modules and how Marchyo uses them.

## What is a Module?

A NixOS module is a file that:
1. Defines options (configuration interface)
2. Provides configuration (system behavior)

## Module Structure

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mymodule;
in {
  # Define options
  options.mymodule = {
    enable = mkEnableOption "my module";

    option1 = mkOption {
      type = types.str;
      default = "value";
      description = "Description of option1";
    };
  };

  # Provide configuration
  config = mkIf cfg.enable {
    # Configuration when module is enabled
  };
}
```

## Module Arguments

Modules receive these arguments:

- `config` - Full system configuration
- `lib` - Nixpkgs library functions
- `pkgs` - Package set
- `options` - All defined options
- Custom arguments via `specialArgs`

In Home Manager modules:

- `osConfig` - Access to NixOS configuration

## Option Types

### Basic Types

```nix
types.bool         # true or false
types.str          # String
types.int          # Integer
types.float        # Floating point
types.path         # File system path
types.package      # Nix package
```

### Composite Types

```nix
types.listOf types.str                  # List of strings
types.attrsOf types.int                 # Attribute set of integers
types.submodule { ... }                 # Nested module
types.either types.str types.int        # String or integer
types.nullOr types.str                  # String or null
types.enum [ "a" "b" "c" ]              # One of specific values
```

## Conditional Configuration

### mkIf - Conditional Config

```nix
config = mkIf cfg.enable {
  # Only applied if cfg.enable is true
};
```

### mkDefault - Overridable Default

```nix
config = {
  myOption = mkDefault "default value";  # Can be overridden
};
```

### mkForce - Force Value

```nix
config = {
  myOption = mkForce "forced value";  # Cannot be overridden
};
```

### mkMerge - Merge Configurations

```nix
config = mkMerge [
  # Always applied
  { services.foo.enable = true; }

  # Conditionally applied
  (mkIf cfg.extraFeature {
    services.bar.enable = true;
  })
];
```

## Module Imports

### Importing Other Modules

```nix
{
  imports = [
    ./module-a.nix
    ./module-b.nix
  ];

  # Module configuration
}
```

### Conditional Imports

```nix
{
  imports = lib.optionals cfg.enable [
    ./extra-module.nix
  ];
}
```

## Marchyo Module Patterns

### Feature Flag Pattern

```nix
# modules/nixos/desktop-config.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.marchyo.desktop;
in {
  config = lib.mkIf cfg.enable {
    # Enable related features
    marchyo.office.enable = lib.mkDefault true;
    marchyo.media.enable = lib.mkDefault true;

    # Configure services
    services.pipewire.enable = true;

    # Install packages
    environment.systemPackages = with pkgs; [
      # Desktop packages
    ];
  };
}
```

### User Configuration Pattern

```nix
# modules/nixos/options.nix
options.marchyo.users = mkOption {
  type = types.attrsOf (types.submodule {
    options = {
      enable = mkEnableOption "Marchyo features for this user";
      fullname = mkOption {
        type = types.str;
        description = "User's full name";
      };
      email = mkOption {
        type = types.str;
        description = "User's email";
      };
    };
  });
};
```

### Cross-Module Communication

```nix
# In Home Manager module
{ config, osConfig, ... }:

{
  programs.git = {
    userName = osConfig.marchyo.users.${config.home.username}.fullname;
    userEmail = osConfig.marchyo.users.${config.home.username}.email;
  };
}
```

## Module Evaluation Process

1. **Collection**: Gather all modules from `imports`
2. **Option Definition**: Merge all `options` definitions
3. **Type Checking**: Validate option types
4. **Config Evaluation**: Evaluate all `config` sections
5. **Merging**: Merge configurations (lists concatenate, attrs merge)
6. **Validation**: Check required options, constraints
7. **Output**: Final system configuration

## Best Practices

### 1. Single Responsibility

Each module should handle one aspect:

```nix
# Good: Desktop module handles desktop concerns
modules/nixos/desktop-config.nix

# Bad: One module doing everything
modules/nixos/everything.nix
```

### 2. Clear Option Descriptions

```nix
description = "Enable Hyprland window manager with Wayland support";
# Not: "Enable hyprland"
```

### 3. Sensible Defaults

```nix
enable = mkEnableOption "feature";  # Defaults to false
package = mkOption {
  type = types.package;
  default = pkgs.mypackage;  # Don't require user to specify
};
```

### 4. Use mkDefault for Auto-Configuration

```nix
# Allow users to override
marchyo.office.enable = mkDefault true;

# Instead of forcing
marchyo.office.enable = true;
```

### 5. Organize by Feature

```
modules/nixos/
├── boot.nix          # Boot configuration
├── desktop.nix       # Desktop environment
├── development.nix   # Development tools
└── ...
```

## Debugging Modules

### Check Option Values

```bash
# See option value
nix eval .#nixosConfigurations.hostname.config.marchyo.desktop.enable

# See all marchyo options
nix eval .#nixosConfigurations.hostname.config.marchyo --show-trace
```

### Test Module Evaluation

```bash
# Build without activating
sudo nixos-rebuild build --flake .#hostname

# Dry run
sudo nixos-rebuild dry-build --flake .#hostname
```

### Find Option Definitions

```bash
# Where is this option defined?
nix eval .#nixosConfigurations.hostname.options.marchyo.desktop.enable.declarations --show-trace
```

## Advanced Patterns

### Assertion Checks

```nix
config = {
  assertions = [
    {
      assertion = cfg.enable -> config.marchyo.desktop.enable;
      message = "This module requires desktop to be enabled";
    }
  ];
};
```

### Warning Messages

```nix
config = {
  warnings = lib.optionals (!cfg.enable) [
    "Module is disabled, some features won't work"
  ];
};
```

### Generated Files

```nix
environment.etc."myapp/config.json".text = builtins.toJSON {
  setting1 = cfg.setting1;
  setting2 = cfg.setting2;
};
```

## See Also

- [NixOS Manual: Writing Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [Architecture](architecture.md) - Marchyo's module organization
- [Adding Modules Tutorial](../tutorials/adding-modules.md) - Practical examples
