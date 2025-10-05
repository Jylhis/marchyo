# Marchyo Configuration Examples

This directory contains example configurations demonstrating different use cases for Marchyo.

## Available Examples

### 1. Minimal Server (`minimal-server.nix`)

A lightweight server configuration without desktop environment.

**Features:**
- No GUI (headless)
- SSH access only
- Minimal packages
- Suitable for VPS, containers, home servers

**Use Cases:**
- Web servers
- Development servers
- CI/CD runners
- Home lab servers

### 2. Developer Workstation (`workstation.nix`)

A full-featured development environment with Hyprland desktop.

**Features:**
- Hyprland desktop environment
- Docker/Podman for containers
- GitHub CLI and development tools
- Office applications
- Modern shell with enhancements

**Use Cases:**
- Software development
- DevOps workstations
- Daily driver for developers

### 3. Gaming Desktop (`gaming-desktop.nix`)

Optimized configuration for gaming performance.

**Features:**
- Hyprland desktop (lightweight for better gaming performance)
- Steam with Proton support
- GameMode performance optimizations
- Gaming-specific kernel parameters
- Low-latency audio configuration
- Media applications

**Use Cases:**
- Gaming-primary systems
- Game development
- Streaming setup

### 4. Flake Template (`flake-template/`)

A ready-to-use flake template for starting your own Marchyo-based configuration.

**Contains:**
- `flake.nix` - Flake definition with Marchyo as input
- `configuration.nix` - Main system configuration template

**Usage:**
```bash
# Create new configuration from template
mkdir my-nixos-config
cd my-nixos-config
cp -r /path/to/marchyo/examples/flake-template/* .

# Generate hardware configuration
nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix

# Edit configuration.nix
# - Change hostname
# - Change username
# - Set your fullname and email
# - Adjust timezone and locale
# - Choose which features to enable

# Initialize git (recommended)
git init
git add .
git commit -m "Initial configuration"

# Build and switch (from live USB or existing system)
sudo nixos-rebuild switch --flake .#hostname
```

## Using These Examples

### Method 1: Direct Copy

Copy the example that matches your use case:

```bash
cp examples/workstation.nix configuration.nix
```

Then edit `configuration.nix` to match your requirements.

### Method 2: Reference in Your Flake

Import examples directly in your flake:

```nix
{
  imports = [
    "${marchyo}/examples/workstation.nix"
    # Your overrides
  ];
}
```

### Method 3: Mix and Match

Take parts from different examples:

```nix
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Gaming optimizations from gaming-desktop.nix
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # Development tools from workstation.nix
  marchyo.development.enable = true;

  # Your specific configuration
  marchyo.users.yourname = {
    enable = true;
    fullname = "Your Name";
    email = "you@example.com";
  };
}
```

## Customization Guide

### Changing Feature Flags

All examples use Marchyo's feature flags. Enable or disable as needed:

```nix
marchyo = {
  desktop.enable = true;       # Hyprland + Wayland + Fonts
  development.enable = true;   # Docker + Dev tools
  media.enable = false;        # Spotify + MPV
  office.enable = true;        # LibreOffice + Viewers
};
```

### Adding Extra Packages

#### System-wide packages:
```nix
environment.systemPackages = with pkgs; [
  firefox
  thunderbird
];
```

#### User-specific packages (Home Manager):
```nix
home-manager.users.yourname = {
  home.packages = with pkgs; [
    neovim
    tmux
  ];
};
```

### Hardware-Specific Configuration

Generate hardware configuration:

```bash
nixos-generate-config --root /mnt
```

This creates `hardware-configuration.nix` with:
- Filesystem mounts
- Boot loader settings
- Hardware-specific modules
- Kernel modules

### Multiple Users

Define multiple users:

```nix
marchyo.users = {
  alice = {
    enable = true;
    fullname = "Alice Smith";
    email = "alice@example.com";
  };
  bob = {
    enable = true;
    fullname = "Bob Jones";
    email = "bob@example.com";
  };
};

users.users = {
  alice = { isNormalUser = true; extraGroups = [ "wheel" ]; };
  bob = { isNormalUser = true; };
};

home-manager.users.alice = { /* ... */ };
home-manager.users.bob = { /* ... */ };
```

## Testing Examples

Test any example in a VM before deploying:

```bash
# Build VM from example
nixos-rebuild build-vm --flake .#hostname

# Run the VM
./result/bin/run-*-vm
```

## Common Modifications

### Change Timezone

```nix
marchyo.timezone = "America/New_York";
time.timeZone = "America/New_York";
```

### Change Locale

```nix
marchyo.defaultLocale = "de_DE.UTF-8";
```

### Enable Auto-Updates

```nix
system.autoUpgrade = {
  enable = true;
  allowReboot = false;
  flake = "github:yourusername/yourconfig";
};
```

### Configure Firewall

```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 80 443 ];
  allowedUDPPorts = [ 51820 ];
};
```

## Next Steps

1. Choose an example matching your use case
2. Copy and customize it
3. Generate `hardware-configuration.nix`
4. Test in a VM (optional but recommended)
5. Deploy to real hardware
6. Fine-tune based on your needs

## Getting Help

- **Documentation**: See `docs/` directory
- **Issues**: Open an issue on GitHub
- **Examples**: Study the module source in `modules/`

## Contributing Examples

Have a useful configuration? Consider contributing:

1. Create a new example file
2. Document it in this README
3. Test thoroughly
4. Submit a pull request

Examples should be:
- Well-commented
- Generic enough for reuse
- Follow Marchyo conventions
- Include clear use case description
