# Troubleshooting

Common issues and solutions.

## Build Errors

### "evaluation aborted"

Check syntax errors:

```bash
nix flake check --show-trace
```

### "infinite recursion"

Module dependency loop. Check your imports and option references.

### "attribute missing"

Ensure all required options are set. Check with:

```bash
nix eval .#nixosConfigurations.myhostname.config --show-trace
```

## Boot Issues

### System Won't Boot

1. Select previous generation from boot menu
2. Press `e` to edit boot entry
3. Boot into previous working configuration

### Grub Menu Not Appearing

Add to configuration:

```nix
boot.loader.timeout = 5;
```

## Network Problems

### No Internet Connection

```bash
# Check network interfaces
ip addr

# Restart NetworkManager
sudo systemctl restart NetworkManager

# Connect to Wi-Fi
nmtui
```

### DNS Not Working

Add to configuration:

```nix
networking.networkmanager.dns = "systemd-resolved";
services.resolved.enable = true;
```

## Graphics Issues

### Black Screen After Login

Switch to TTY (Ctrl+Alt+F2) and check logs:

```bash
journalctl -xeu display-manager
```

### Poor Performance

Enable hardware acceleration:

```nix
hardware.opengl = {
  enable = true;
  driSupport = true;
  driSupport32Bit = true;  # For gaming
};
```

## Hyprland Issues

### Hyprland Won't Start

Check logs:

```bash
journalctl --user -u hyprland
```

### Screen Tearing

Enable VRR:

```nix
wayland.windowManager.hyprland.settings = {
  misc.vrr = 1;
};
```

## Package Issues

### Package Not Found

Update flake:

```bash
nix flake update
```

### Unfree Package

Enable unfree:

```nix
nixpkgs.config.allowUnfree = true;
```

## Home Manager Issues

### Home Manager Config Not Applied

Rebuild home-manager:

```bash
home-manager switch --flake /etc/nixos#myuser@myhostname
```

### Permission Denied

Check file ownership:

```bash
sudo chown -R $USER:users ~/.config
```

## Disk Space

### /nix/store Full

Remove old generations:

```bash
# Remove old system generations
sudo nix-collect-garbage -d

# Remove old user generations
nix-collect-garbage -d

# Optimize store
sudo nix-store --optimize
```

## Getting More Help

1. Check [NixOS Manual](https://nixos.org/manual/nixos/stable/)
2. Search [NixOS Discourse](https://discourse.nixos.org/)
3. Ask on [GitHub Discussions](https://github.com/Jylhis/marchyo/discussions)
4. Join [NixOS Matrix](https://matrix.to/#/#community:nixos.org)
