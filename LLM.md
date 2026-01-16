# Marchyo - AI Assistant Guide

This document helps AI assistants guide users in configuring Marchyo, a modular NixOS configuration flake.

## What is Marchyo?

Marchyo provides pre-configured NixOS modules with sensible defaults for desktop environments, development tools, and system configuration. Users enable feature flags and Marchyo handles the underlying complexity.

## Quick Start

Add to user's `flake.nix`:

```nix
{
  inputs.marchyo.url = "github:Jylhis/marchyo";

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";  # or "aarch64-linux"
      modules = [
        marchyo.nixosModules.default
        ./hardware-configuration.nix
        {
          # User configuration
          marchyo.users.username = {
            fullname = "Full Name";
            email = "email@example.com";
          };

          # Enable features
          marchyo.desktop.enable = true;
          marchyo.development.enable = true;
        }
      ];
    };
  };
}
```

Or use the template: `nix flake init -t github:Jylhis/marchyo#workstation`

## Available Options

### Feature Flags

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.desktop.enable` | `false` | Desktop environment (Hyprland, audio, bluetooth, fonts) |
| `marchyo.development.enable` | `false` | Development tools (git, docker, virtualization) |
| `marchyo.media.enable` | `false` | Media apps (auto-enabled by desktop) |
| `marchyo.office.enable` | `false` | Office apps (auto-enabled by desktop) |

### User Configuration

```nix
marchyo.users.<username> = {
  enable = true;  # default
  fullname = "Your Name";
  email = "your@email.com";
};
```

### Localization

| Option | Default | Example |
|--------|---------|---------|
| `marchyo.timezone` | `"Europe/Zurich"` | `"America/New_York"` |
| `marchyo.defaultLocale` | `"en_US.UTF-8"` | `"de_DE.UTF-8"` |

### Theming

```nix
marchyo.theme = {
  enable = true;  # default
  variant = "dark";  # or "light"
  scheme = "dracula";  # or any nix-colors scheme, or null for defaults
};
```

Default schemes: `modus-vivendi-tinted` (dark), `modus-operandi-tinted` (light).

### Keyboard & Input Methods

```nix
marchyo.keyboard = {
  layouts = [
    "us"                                    # Simple layout
    { layout = "fi"; }                      # Simple layout (explicit)
    { layout = "us"; variant = "intl"; }   # Layout with variant
    { layout = "cn"; ime = "pinyin"; }     # Chinese with Pinyin
    { layout = "jp"; ime = "mozc"; }       # Japanese with Mozc
    { layout = "kr"; ime = "hangul"; }     # Korean with Hangul
  ];
  options = [ "grp:win_space_toggle" ];    # Super+Space to switch
  autoActivateIME = true;                   # Auto-activate IME on switch
  imeTriggerKey = [ "Super+I" ];           # Manual IME toggle
};
```

### Graphics (GPU)

```nix
marchyo.graphics = {
  vendors = [ "intel" ];  # "intel", "amd", "nvidia"

  # NVIDIA-specific
  nvidia = {
    open = true;           # Open-source drivers (RTX 20xx+)
    powerManagement = false;
  };

  # Hybrid graphics (laptop with two GPUs)
  prime = {
    enable = true;
    intelBusId = "PCI:0:2:0";    # or amdgpuBusId
    nvidiaBusId = "PCI:1:0:0";
    mode = "offload";  # "offload", "sync", "reverse-sync"
  };
};
```

Find GPU bus IDs: `lspci | grep -E 'VGA|3D'`

## What Each Feature Enables

### `marchyo.desktop.enable = true`

- Hyprland (Wayland compositor)
- Pipewire (audio)
- Bluetooth (blueman)
- Printing (CUPS)
- Fonts (Nerd Fonts, CJK support)
- Power management
- XDG portals
- Auto-enables `media` and `office`

### `marchyo.development.enable = true`

- Git with LFS
- Docker with auto-prune
- libvirtd (QEMU/KVM)
- direnv
- CLI tools: gh, ripgrep, fd, jq, yq, etc.

## Common Tasks

### Add a New User

```nix
marchyo.users.newuser = {
  fullname = "New User";
  email = "new@example.com";
};
users.users.newuser = {
  isNormalUser = true;
  extraGroups = [ "wheel" "docker" ];
};
```

### Change Theme

```nix
marchyo.theme.scheme = "catppuccin-mocha";  # or "gruvbox-dark-medium", etc.
```

### Add Chinese Input

```nix
marchyo.keyboard.layouts = [
  "us"
  { layout = "cn"; ime = "pinyin"; }
];
```

### Configure Hybrid Graphics Laptop

```nix
marchyo.graphics = {
  vendors = [ "intel" "nvidia" ];
  prime = {
    enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    mode = "offload";
  };
};
```

## Breaking Changes & Migration

### Keyboard/IME Migration

**Old (deprecated):**
```nix
marchyo.inputMethod.enable = true;
marchyo.inputMethod.enableCJK = true;
marchyo.keyboard.layouts = ["us" "fi"];
```

**New:**
```nix
marchyo.keyboard.layouts = [
  "us"
  "fi"
  { layout = "cn"; ime = "pinyin"; }
];
```

### Deprecated Options

These options still work but will be removed:
- `marchyo.keyboard.variant` - Use `{ layout = "us"; variant = "intl"; }` instead
- `marchyo.inputMethod.*` - Use `marchyo.keyboard.layouts` with `ime` attribute

## Validation

After changes, run:
```bash
nix flake check  # Validate configuration
nix fmt          # Format code (if contributing)
```

## Flake Outputs Reference

- `nixosModules.default` - Main module (includes Home Manager)
- `homeModules.default` - Home Manager module only
- `templates.workstation` - Starter template
- `lib.marchyo.colorSchemes` - Custom color schemes
- `overlays.default` - Nixpkgs overlay
