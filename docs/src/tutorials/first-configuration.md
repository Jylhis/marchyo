# First Configuration

Now that you have Marchyo installed, let's customize it to fit your needs.

## Understanding Your Configuration

Your NixOS configuration consists of three main files:

- **`flake.nix`** - Defines inputs and outputs for your system
- **`configuration.nix`** - Your system configuration
- **`hardware-configuration.nix`** - Auto-generated hardware settings (don't modify)

## Basic Customization

### Change Your Hostname

Edit `configuration.nix`:

```nix
networking.hostName = "my-awesome-machine";
```

### Update User Information

```nix
marchyo.users.myuser = {
  enable = true;
  fullname = "Jane Doe";
  email = "jane@example.com";
};
```

This will automatically configure git with your name and email.

### Choose Your Color Scheme

Marchyo supports 200+ color schemes. To change yours:

```nix
marchyo.theme = {
  enable = true;
  variant = "dark";  # or "light"
  scheme = "gruvbox-dark-medium";  # or any nix-colors scheme
};
```

Popular schemes:
- `modus-vivendi-tinted` - Dark theme (default)
- `modus-operandi-tinted` - Light theme
- `dracula` - Dracula theme
- `catppuccin-mocha` - Catppuccin Mocha
- `gruvbox-dark-medium` - Gruvbox Dark
- `nord` - Nord theme
- `tokyo-night-dark` - Tokyo Night

See [Color Schemes](../reference/color-schemes.md) for the full list.

### Enable/Disable Features

Marchyo uses feature flags for easy customization:

```nix
marchyo = {
  # Desktop environment (Hyprland, fonts, audio, etc.)
  desktop.enable = true;

  # Development tools (Docker, git, build tools, etc.)
  development.enable = true;

  # Media apps (Spotify, MPV)
  media.enable = true;

  # Office apps (LibreOffice, Papers)
  office.enable = true;
};
```

## Adding System Packages

To add system-wide packages:

```nix
environment.systemPackages = with pkgs; [
  firefox
  thunderbird
  gimp
  # Add your packages here
];
```

## Adding Home Manager Packages

For user-specific packages, add to your home-manager configuration:

```nix
home-manager.users.myuser = {
  home.packages = with pkgs; [
    discord
    steam
    # User-specific packages
  ];
};
```

## Applying Changes

After editing your configuration:

```bash
# Test the build (doesn't apply changes)
sudo nixos-rebuild dry-build --flake /etc/nixos#myhostname

# Apply the changes
sudo nixos-rebuild switch --flake /etc/nixos#myhostname
```

## Useful Rebuild Commands

```bash
# Build and switch to new configuration
sudo nixos-rebuild switch --flake /etc/nixos#myhostname

# Build but don't activate (activate on next boot)
sudo nixos-rebuild boot --flake /etc/nixos#myhostname

# Test configuration (revert on reboot)
sudo nixos-rebuild test --flake /etc/nixos#myhostname

# Build without activating
sudo nixos-rebuild build --flake /etc/nixos#myhostname
```

## Managing Generations

NixOS keeps previous system configurations (generations):

```bash
# List all generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Boot into a specific generation
# Select from the boot menu on next reboot
```

## Setting Up Git for Your Configuration

Track your configuration with git:

```bash
cd /etc/nixos
git init
git add .
git commit -m "Initial Marchyo configuration"

# Optional: Push to GitHub
gh repo create my-nixos-config --private
git remote add origin git@github.com:yourusername/my-nixos-config.git
git push -u origin main
```

## Common Customizations

### Set Timezone

```nix
marchyo.timezone = "America/New_York";
```

### Set Locale

```nix
marchyo.defaultLocale = "en_GB.UTF-8";
```

### Enable SSH

```nix
services.openssh = {
  enable = true;
  settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };
};
```

### Configure Automatic Updates

```nix
system.autoUpgrade = {
  enable = true;
  flake = "/etc/nixos";
  flags = [
    "--update-input" "nixpkgs"
    "--commit-lock-file"
  ];
  dates = "weekly";
};
```

## Next Steps

- [Adding Modules](adding-modules.md) - Learn about the module system
- [Configure Desktop](../how-to/configure-desktop.md) - Customize Hyprland
- [Feature Flags Reference](../reference/feature-flags.md) - Complete list of options

## Getting Help

- Check [Troubleshooting](../how-to/troubleshooting.md) for common issues
- Review [Module Options](../reference/modules/nixos-options.md) for all available options
- Join discussions on [GitHub](https://github.com/Jylhis/marchyo/discussions)
