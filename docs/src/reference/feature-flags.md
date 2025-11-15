# Feature Flags

High-level configuration options for enabling groups of functionality.

## Overview

Marchyo uses feature flags under the `marchyo.*` namespace to enable related packages and services with a single option.

## Available Feature Flags

### `marchyo.desktop.enable`

**Type**: Boolean
**Default**: `false`
**Description**: Enable desktop environment with Hyprland

**Automatically enables:**
- Hyprland window manager
- Audio (PipeWire)
- Bluetooth
- Fonts (Nerd Fonts, Inter, Source Serif Pro)
- Printing support
- Geolocation services
- File thumbnails
- XDG portals
- Office applications (by default)
- Media applications (by default)

**Example:**
```nix
marchyo.desktop.enable = true;
```

### `marchyo.development.enable`

**Type**: Boolean
**Default**: `false`
**Description**: Enable development tools and environments

**Automatically enables:**
- Git (with LFS support)
- GitHub CLI (gh)
- Docker with auto-prune
- libvirtd / QEMU / KVM
- Direnv with nix-direnv
- Build tools (gcc, make, cmake, pkg-config)
- Container tools (docker-compose, lazydocker)
- VM tools (virt-manager, virt-viewer)
- Network utilities (nmap, tcpdump, curl, wget)
- Development utilities (jq, yq, sqlite)

**Example:**
```nix
marchyo.development.enable = true;
```

### `marchyo.media.enable`

**Type**: Boolean
**Default**: `false` (auto-enabled when `desktop.enable = true`)
**Description**: Enable media applications

**Packages:**
- mpv (video player)
- Spotify (requires `allowUnfree = true`)
- libheif (HEIF image support)

**Example:**
```nix
marchyo.media.enable = true;
nixpkgs.config.allowUnfree = true;  # For Spotify
```

### `marchyo.office.enable`

**Type**: Boolean
**Default**: `false` (auto-enabled when `desktop.enable = true`)
**Description**: Enable office applications

**Packages:**
- LibreOffice
- Papers (document manager)
- Xournalpp (PDF annotation)

**Example:**
```nix
marchyo.office.enable = true;
```

### `marchyo.desktop.useWofi`

**Type**: Boolean
**Default**: `false`
**Description**: Use wofi launcher instead of vicinae

**Example:**
```nix
marchyo.desktop = {
  enable = true;
  useWofi = true;
};
```

## Theme Configuration

### `marchyo.theme.enable`

**Type**: Boolean
**Default**: `true`
**Description**: Enable theming system

### `marchyo.theme.variant`

**Type**: String ("light" or "dark")
**Default**: `"dark"`
**Description**: Theme variant

### `marchyo.theme.scheme`

**Type**: String or Attribute Set or null
**Default**: `null` (uses variant default)
**Description**: Color scheme name or custom scheme

**Examples:**

```nix
# Use a nix-colors scheme by name
marchyo.theme = {
  enable = true;
  variant = "dark";
  scheme = "dracula";
};

# Use custom scheme
marchyo.theme = {
  enable = true;
  scheme = {
    slug = "my-theme";
    name = "My Theme";
    author = "Me";
    variant = "dark";
    palette = {
      base00 = "000000";
      # ... base01-base0F
    };
  };
};
```

## User Configuration

### `marchyo.users.<username>.enable`

**Type**: Boolean
**Default**: `true`
**Description**: Enable Marchyo configuration for user

### `marchyo.users.<username>.fullname`

**Type**: String
**Description**: User's full name (used in git config)

### `marchyo.users.<username>.email`

**Type**: String
**Description**: User's email address (used in git config)

**Example:**

```nix
marchyo.users.alice = {
  enable = true;
  fullname = "Alice Smith";
  email = "alice@example.com";
};
```

## Locale Configuration

### `marchyo.timezone`

**Type**: String
**Default**: `"Europe/Zurich"`
**Example**: `"America/New_York"`

### `marchyo.defaultLocale`

**Type**: String
**Default**: `"en_US.UTF-8"`
**Example**: `"de_DE.UTF-8"`

## Complete Example

```nix
{ config, pkgs, ... }:

{
  # Enable feature flags
  marchyo = {
    # Desktop environment
    desktop = {
      enable = true;
      useWofi = false;  # Use vicinae (default)
    };

    # Development tools
    development.enable = true;

    # Media and office (auto-enabled with desktop)
    media.enable = true;
    office.enable = true;

    # Theming
    theme = {
      enable = true;
      variant = "dark";
      scheme = "gruvbox-dark-medium";
    };

    # User configuration
    users.alice = {
      enable = true;
      fullname = "Alice Smith";
      email = "alice@example.com";
    };

    # Locale settings
    timezone = "America/New_York";
    defaultLocale = "en_US.UTF-8";
  };

  # Create user account
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Allow unfree (for Spotify, etc.)
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
```

## See Also

- [NixOS Module Options](modules/nixos-options.md) - Complete options reference
- [Color Schemes](color-schemes.md) - Available themes
- [First Configuration](../tutorials/first-configuration.md) - Configuration tutorial
