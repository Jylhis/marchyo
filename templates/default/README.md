# Marchyo Configuration Template

This is a basic Marchyo configuration with a minimal desktop setup.

## Quick Start

1. **Initialize your configuration**:
   ```bash
   nix flake init -t github:marchyo/marchyo
   ```

2. **Generate hardware configuration**:
   ```bash
   nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```

3. **Customize configuration.nix**:
   - Change `networking.hostName` to your desired hostname
   - Update `marchyo.users.myuser` with your username and details
   - Adjust timezone and locale settings
   - Enable/disable desktop environment

4. **Build and switch**:
   ```bash
   sudo nixos-rebuild switch --flake .#my-system
   ```

## Customization

### Enable Desktop Environment

The template includes Hyprland by default. To enable it:

```nix
marchyo.desktop.hyprland.enable = true;
```

### Add More Users

```nix
marchyo.users.anotheruser = {
  enable = true;
  fullname = "Another User";
  email = "another@example.com";
};
```

### Add System Packages

```nix
environment.systemPackages = with pkgs; [
  vim
  git
  firefox
  # Add more packages here
];
```

## Next Steps

- Review `/etc/nixos/configuration.nix` for additional options
- Check Marchyo modules in `marchyo.` namespace for available features
- Read the [NixOS manual](https://nixos.org/manual/nixos/stable/) for more options

## Updating

Update your system and Marchyo:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#my-system
```
