# Configuration Guide

This guide explains how to configure your Marchyo-based NixOS system using the `marchyo.*` options.

## Table of Contents

- [Overview](#overview)
- [Feature Flags](#feature-flags)
- [User Configuration](#user-configuration)
- [System Settings](#system-settings)
- [Common Configuration Patterns](#common-configuration-patterns)
- [Overriding Marchyo Defaults](#overriding-marchyo-defaults)
- [Multi-User Setups](#multi-user-setups)
- [Advanced Configuration](#advanced-configuration)

## Overview

Marchyo provides a high-level configuration interface through the `marchyo.*` namespace in your NixOS configuration. These options abstract common patterns and provide sensible defaults while remaining fully customizable.

### Configuration Structure

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    # Feature flags
    desktop.enable = true;
    development.enable = false;
    media.enable = false;
    office.enable = false;

    # System settings
    timezone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";

    # User configuration
    users.yourusername = {
      enable = true;
      fullname = "Your Name";
      email = "you@example.com";
    };
  };
}
```

## Feature Flags

Feature flags enable or disable groups of related functionality. All feature flags default to `false`, so you explicitly enable only what you need.

### marchyo.desktop.enable

Enables the complete desktop environment experience.

**Type:** `boolean`
**Default:** `false`

**Includes:**
- Hyprland (dynamic tiling Wayland compositor)
- Wayland support and protocols
- Display manager (GDM)
- Desktop GUI applications (Signal, Brave, Nautilus, etc.)
- Font configuration with popular fonts
- Graphics and OpenGL support
- Audio support (PipeWire)
- Bluetooth management
- Screenshot and screen recording tools

**Example:**

```nix
marchyo.desktop.enable = true;
```

**Installed Packages:**
- `signal-desktop` - E2E messaging
- `brave` - Privacy-focused browser
- `localsend` - Local file sharing
- `file-roller` - Archive manager
- `nautilus` - File explorer

### marchyo.development.enable

Enables development tools and container support.

**Type:** `boolean`
**Default:** `false`

**Includes:**
- Docker with Compose
- Buildah and Skopeo (container management)
- GitHub CLI (`gh`)
- Lazydocker (Docker TUI)

**Example:**

```nix
marchyo.development.enable = true;

# This automatically enables:
# - Docker daemon
# - Docker Compose
# - Container build tools
```

**Additional Configuration:**

```nix
# Add yourself to docker group for non-root access
users.users.yourusername = {
  extraGroups = [ "docker" ];
};
```

### marchyo.media.enable

Enables media playback and basic editing applications.

**Type:** `boolean`
**Default:** `false`

**Includes:**
- MPV (video player)
- Pinta (basic image editor)

**Example:**

```nix
marchyo.media.enable = true;
```

### marchyo.office.enable

Enables office and productivity applications.

**Type:** `boolean`
**Default:** `false`

**Includes:**
- LibreOffice (full office suite)
- Papers (document viewer)
- Xournalpp (PDF annotation)
- Obsidian (note-taking)

**Example:**

```nix
marchyo.office.enable = true;
```

## User Configuration

The `marchyo.users` option defines user-specific settings and metadata. This integrates with Home Manager to provide per-user configurations.

### marchyo.users.\<name>

**Type:** `attribute set of submodules`
**Default:** `{}`

Each user has the following options:

#### enable

Whether to enable Marchyo configuration for this user.

**Type:** `boolean`
**Default:** `true`

**Example:**

```nix
marchyo.users.alice = {
  enable = false;  # Disable Marchyo features for this user
  fullname = "Alice Smith";
  email = "alice@example.com";
};
```

#### name

The username. Automatically derived from the attribute name.

**Type:** `string`
**Default:** (attribute name)

**Example:**

```nix
# These are equivalent:
marchyo.users.bob = { ... };

marchyo.users.bob = {
  name = "bob";  # Redundant but explicit
  ...
};
```

#### fullname

User's full name. Used for git configuration and other applications.

**Type:** `string`
**Required:** Yes

**Example:**

```nix
marchyo.users.charlie = {
  fullname = "Charlie Brown";
  email = "charlie@example.com";
};
```

#### email

User's email address. Used for git configuration and other applications.

**Type:** `string`
**Required:** Yes

**Example:**

```nix
marchyo.users.dave = {
  fullname = "Dave Miller";
  email = "dave@company.com";
};
```

## System Settings

System-wide configuration options that affect all users.

### marchyo.timezone

System timezone.

**Type:** `string`
**Default:** `"Europe/Zurich"`

**Example:**

```nix
marchyo.timezone = "America/New_York";
# or
marchyo.timezone = "Asia/Tokyo";
# or
marchyo.timezone = "UTC";
```

**Note:** You do NOT need to set `time.timeZone` separately - Marchyo sets it automatically based on this option.

### marchyo.defaultLocale

System default locale for language and regional settings.

**Type:** `string`
**Default:** `"en_US.UTF-8"`

**Example:**

```nix
marchyo.defaultLocale = "de_DE.UTF-8";  # German
# or
marchyo.defaultLocale = "fr_FR.UTF-8";  # French
# or
marchyo.defaultLocale = "ja_JP.UTF-8";  # Japanese
```

**Note:** You do NOT need to set `i18n.defaultLocale` separately - Marchyo sets it automatically.

## Common Configuration Patterns

### Minimal Desktop Setup

Perfect for lightweight systems or getting started:

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    desktop.enable = true;

    users.user = {
      fullname = "User Name";
      email = "user@example.com";
    };
  };
}
```

### Developer Workstation

Full-featured development environment:

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    desktop.enable = true;
    development.enable = true;
    office.enable = true;

    timezone = "America/Los_Angeles";

    users.developer = {
      fullname = "Dev Name";
      email = "dev@company.com";
    };
  };

  # Add extra development tools
  environment.systemPackages = with pkgs; [
    vscode
    postman
    dbeaver-bin
  ];
}
```

### Home Office Setup

Desktop with productivity tools:

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    desktop.enable = true;
    office.enable = true;
    media.enable = true;

    timezone = "Europe/London";

    users.worker = {
      fullname = "Worker Name";
      email = "worker@remote.com";
    };
  };

  # Add communication tools
  environment.systemPackages = with pkgs; [
    slack
    zoom-us
    thunderbird
  ];
}
```

### Gaming Desktop

Minimal overhead for performance:

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    desktop.enable = true;
    media.enable = true;

    users.gamer = {
      fullname = "Gamer Name";
      email = "gamer@example.com";
    };
  };

  # Gaming-specific configuration
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  hardware.graphics.enable32Bit = true;
}
```

### Headless Server

No desktop, minimal packages:

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    # All feature flags default to false

    timezone = "UTC";

    users.admin = {
      fullname = "System Administrator";
      email = "admin@server.com";
    };
  };

  # Server-specific configuration
  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
}
```

## Overriding Marchyo Defaults

Marchyo's configurations use NixOS's module system, so you can override any option.

### Override Feature Flag Packages

Add or remove packages from feature flags:

```nix
{ config, pkgs, ... }:

{
  marchyo.desktop.enable = true;

  # Remove a package Marchyo installs
  environment.systemPackages = pkgs.lib.mkForce (
    builtins.filter (pkg: pkg.pname or "" != "brave")
      config.environment.systemPackages
  );

  # Or add your preferred browser
  environment.systemPackages = [ pkgs.firefox ];
}
```

### Override Hyprland Configuration

Marchyo configures Hyprland, but you can extend or override it:

```nix
{ config, ... }:

{
  marchyo.desktop.enable = true;

  # Extend Hyprland config
  wayland.windowManager.hyprland.extraConfig = ''
    # Custom keybindings
    bind = SUPER, F, fullscreen, 1

    # Custom window rules
    windowrule = float, ^(my-app)$
  '';
}
```

### Override Shell Configuration

Customize the shell experience:

```nix
{ config, ... }:

{
  # Marchyo enables fish by default
  # Switch to zsh instead:
  users.users.yourusername = {
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
```

### Disable Specific Services

Marchyo enables certain services automatically:

```nix
{ config, ... }:

{
  marchyo.desktop.enable = true;

  # Disable Tailscale if you don't need it
  services.tailscale.enable = pkgs.lib.mkForce false;
}
```

## Multi-User Setups

Marchyo supports configuring multiple users with different profiles.

### Multiple Users Example

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    desktop.enable = true;
    development.enable = true;
    office.enable = true;

    users = {
      alice = {
        fullname = "Alice Developer";
        email = "alice@company.com";
      };

      bob = {
        fullname = "Bob Designer";
        email = "bob@company.com";
      };

      guest = {
        enable = false;  # Disable Marchyo config for guest
        fullname = "Guest User";
        email = "guest@localhost";
      };
    };
  };

  # Define actual user accounts
  users.users = {
    alice = {
      isNormalUser = true;
      extraGroups = [ "wheel" "docker" "networkmanager" ];
      initialPassword = "changeme";
    };

    bob = {
      isNormalUser = true;
      extraGroups = [ "networkmanager" ];
      initialPassword = "changeme";
    };

    guest = {
      isNormalUser = true;
      # Minimal permissions
    };
  };

  # Per-user Home Manager configuration
  home-manager.users.alice = {
    # Alice gets developer tools
    home.packages = with pkgs; [ vscode postman ];
  };

  home-manager.users.bob = {
    # Bob gets design tools
    home.packages = with pkgs; [ gimp inkscape ];
  };
}
```

### User-Specific Feature Flags

Currently, feature flags are system-wide. For per-user packages, use Home Manager:

```nix
{ config, pkgs, ... }:

{
  marchyo = {
    desktop.enable = true;
    # Don't enable development system-wide
  };

  # Only alice gets development tools via Home Manager
  home-manager.users.alice = {
    home.packages = with pkgs; [
      docker-compose
      gh
      vscode
    ];
  };

  home-manager.users.bob = {
    home.packages = with pkgs; [
      # Bob gets different packages
    ];
  };
}
```

## Advanced Configuration

### Using Marchyo as a Module

Marchyo is designed as a NixOS module, meaning it integrates seamlessly:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:Jylhis/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        marchyo.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Conditional Configuration

Use NixOS conditions to adapt configuration:

```nix
{ config, lib, ... }:

{
  marchyo = {
    # Enable desktop only on machines with enough RAM
    desktop.enable = lib.mkIf (config.boot.kernelPackages != null) true;

    # Enable development on workstations
    development.enable = lib.mkIf
      (config.networking.hostName == "workstation")
      true;
  };
}
```

### Profile-Based Configuration

Create configuration profiles:

```nix
# profiles/desktop.nix
{ ... }:
{
  marchyo = {
    desktop.enable = true;
    media.enable = true;
    office.enable = true;
  };
}

# profiles/server.nix
{ ... }:
{
  marchyo = {
    # All disabled by default
  };

  services.openssh.enable = true;
}

# configuration.nix
{ ... }:
{
  imports = [
    ./profiles/desktop.nix  # or ./profiles/server.nix
  ];

  marchyo.users.user = {
    fullname = "User Name";
    email = "user@example.com";
  };
}
```

### Accessing Marchyo Configuration

Access Marchyo options in your own modules:

```nix
{ config, ... }:

{
  # Check if desktop is enabled
  services.myservice.enable = config.marchyo.desktop.enable;

  # Use user email in configuration
  programs.git.userEmail = config.marchyo.users.yourusername.email;
}
```

## Troubleshooting

### My configuration isn't applying

Ensure you've imported the Marchyo module in your flake:

```nix
# flake.nix
nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
  modules = [
    marchyo.nixosModules.default  # ← Must be present
    ./configuration.nix
  ];
};
```

### Feature flags don't seem to work

Check that you've set `enable = true`:

```nix
# Wrong (no effect):
marchyo.desktop = true;

# Correct:
marchyo.desktop.enable = true;
```

### Conflicts with existing configuration

Use `lib.mkForce` to override:

```nix
{ lib, ... }:

{
  marchyo.desktop.enable = true;

  # Override a service Marchyo enables
  services.someservice.enable = lib.mkForce false;
}
```

### Can't find user configuration

Ensure Home Manager is configured:

```nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  users.yourusername = {
    imports = [ marchyo.homeModules.default ];
    home.stateVersion = "24.11";
  };
};
```

## Next Steps

- [Module Reference](modules-reference.md) - Detailed documentation of all modules
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Examples](../examples/) - Complete configuration examples

## Getting Help

- Check the [examples/](../examples/) directory for working configurations
- Review [installation.md](installation.md) for setup instructions
- Open an issue on GitHub for bugs or questions
