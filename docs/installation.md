# Installation Guide

This guide covers various methods for installing and configuring Marchyo.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Method 1: From Existing NixOS](#method-1-from-existing-nixos)
- [Method 2: Standalone Home Manager](#method-2-standalone-home-manager)
- [Method 3: New NixOS Installation](#method-3-new-nixos-installation)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### For NixOS Installation

- NixOS 24.05 or later
- Flakes enabled in Nix configuration
- Git installed
- Basic familiarity with Nix

### Enable Flakes

If flakes are not enabled, add to `/etc/nixos/configuration.nix`:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

### For Home Manager Only

- Nix package manager with flakes enabled
- Linux or macOS
- User account with write permissions

## Method 1: From Existing NixOS

The most common installation method - add Marchyo to your existing NixOS system.

### Step 1: Create or Update flake.nix

In your NixOS configuration directory (typically `/etc/nixos/`):

```nix
{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    marchyo = {
      url = "github:Jylhis/marchyo";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, marchyo, home-manager, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        marchyo.nixosModules.default
        home-manager.nixosModules.home-manager
        ./configuration.nix
      ];
    };
  };
}
```

### Step 2: Update configuration.nix

```nix
{ config, pkgs, lib, ... }:

{
  # Import hardware configuration
  imports = [ ./hardware-configuration.nix ];

  # System settings
  networking.hostName = "yourhostname";

  # Marchyo configuration
  marchyo = {
    desktop.enable = true;
    development.enable = true;

    timezone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";

    users.yourusername = {
      enable = true;
      fullname = "Your Name";
      email = "you@example.com";
    };
  };

  # User account
  users.users.yourusername = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.yourusername = {
      imports = [ marchyo.homeModules.default ];
      home.stateVersion = "24.11";
    };
  };

  system.stateVersion = "24.11";
}
```

### Step 3: Build and Switch

```bash
# Lock dependencies
sudo nix flake lock

# Test build (doesn't activate)
sudo nixos-rebuild build --flake .#yourhostname

# Preview changes
nix store diff-closures /run/current-system ./result

# Switch to new configuration
sudo nixos-rebuild switch --flake .#yourhostname
```

### Step 4: Reboot

```bash
sudo reboot
```

After reboot, Hyprland should be available in your display manager.

## Method 2: Standalone Home Manager

Use Marchyo's Home Manager modules without NixOS.

### Step 1: Install Home Manager

Follow [Home Manager installation](https://nix-community.github.io/home-manager/#sec-install-standalone).

### Step 2: Create flake.nix

```nix
{
  description = "Home Manager Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    marchyo = {
      url = "github:Jylhis/marchyo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, marchyo, ... }: {
    homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        marchyo.homeModules.default
        ./home.nix
      ];
    };
  };
}
```

### Step 3: Create home.nix

```nix
{ config, pkgs, ... }:

{
  home = {
    username = "yourusername";
    homeDirectory = "/home/yourusername";
    stateVersion = "24.11";

    packages = with pkgs; [
      # Add packages here
    ];
  };

  # Enable Marchyo modules as needed
  programs = {
    git.enable = true;
    kitty.enable = true;
    # Other programs...
  };
}
```

### Step 4: Activate

```bash
home-manager switch --flake .#yourusername
```

## Method 3: New NixOS Installation

Install NixOS with Marchyo from scratch.

### Step 1: Boot NixOS Installer

Boot from NixOS installation media (download from nixos.org).

### Step 2: Partition Disks

Example UEFI setup:

```bash
# Partition disk
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart primary 512MB 100%

# Format partitions
sudo mkfs.fat -F 32 -n boot /dev/sda1
sudo mkfs.ext4 -L nixos /dev/sda2

# Mount
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

### Step 3: Generate Initial Configuration

```bash
sudo nixos-generate-config --root /mnt
```

### Step 4: Create Flake Configuration

```bash
cd /mnt/etc/nixos
```

Copy one of the examples from `marchyo/examples/` or create `flake.nix` as shown in Method 1.

### Step 5: Install

```bash
# Test configuration
sudo nixos-install --flake .#yourhostname --no-root-passwd --dry-run

# Install
sudo nixos-install --flake .#yourhostname --no-root-passwd

# Set user password
sudo nixos-enter
passwd yourusername
exit
```

### Step 6: Reboot

```bash
sudo reboot
```

## Post-Installation

### Verify Installation

After rebooting:

```bash
# Check Hyprland is installed
which Hyprland

# Check your user configuration
id yourusername

# Verify Home Manager
home-manager --version
```

### First Login

1. Select Hyprland from display manager
2. Login with your credentials
3. Press Super+R to open Wofi launcher
4. Press Super+Return to open terminal

### Update System

```bash
# Update flake lock
cd /etc/nixos
sudo nix flake update

# Rebuild
sudo nixos-rebuild switch --flake .#yourhostname
```

### Enable Binary Cache (Optional)

Add to your configuration:

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://marchyo.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    # Add Marchyo cache key when available
  ];
};
```

## Troubleshooting

### Flakes Not Enabled

Error: `error: experimental Nix feature 'flakes' is disabled`

**Solution:**

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### Build Fails

**Check logs:**

```bash
sudo nixos-rebuild switch --flake .#yourhostname --show-trace
```

**Common issues:**
- Syntax errors in configuration.nix
- Missing hardware-configuration.nix
- Incorrect hostname in flake.nix

### Hyprland Doesn't Start

**Check display manager:**

```bash
systemctl status display-manager
```

**Check Hyprland logs:**

```bash
journalctl --user -u hyprland
```

### Home Manager Errors

**Rebuild Home Manager only:**

```bash
home-manager switch --flake .#yourusername
```

**Check Home Manager service:**

```bash
systemctl --user status home-manager-yourusername.service
```

### Roll Back Changes

If something breaks:

**From boot menu:**
- Select previous generation at boot

**From terminal:**

```bash
sudo nixos-rebuild switch --rollback
```

### Git Issues with Flakes

**Cache flake to avoid refetching:**

```bash
nix flake update --commit-lock-file
```

### Permission Errors

Ensure proper ownership:

```bash
sudo chown -R yourusername:users /home/yourusername
```

## Next Steps

- [Configuration Guide](configuration.md) - Customize your system
- [Module Reference](modules-reference.md) - Available modules and options
- [Examples](../examples/) - Pre-configured setups

## Getting Help

- Check [Troubleshooting Guide](troubleshooting.md)
- Review [examples/](../examples/)
- Open an issue on GitHub
- Ask in NixOS community channels
