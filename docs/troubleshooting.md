# Troubleshooting Guide

Common issues, debugging techniques, and solutions for Marchyo-based NixOS systems.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Installation Issues](#installation-issues)
- [Build & Configuration Errors](#build--configuration-errors)
- [Desktop Environment Issues](#desktop-environment-issues)
- [Module & Feature Flag Problems](#module--feature-flag-problems)
- [Home Manager Issues](#home-manager-issues)
- [System Recovery](#system-recovery)
- [Debugging Tools & Techniques](#debugging-tools--techniques)
- [Getting Help](#getting-help)

## Quick Diagnostics

Run these commands to quickly assess your system state:

```bash
# Check system health
./scripts/health-check.sh --verbose

# Validate flake configuration
nix flake check

# View recent errors
journalctl -b -p err --no-pager | tail -20

# Check failed services
systemctl --failed

# Verify current generation
readlink -f /run/current-system
```

## Installation Issues

### Flakes Not Enabled

**Error:**
```
error: experimental Nix feature 'flakes' is disabled
```

**Solution:**

Add to `/etc/nixos/configuration.nix`:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

**Note:** This is a chicken-and-egg problem. You must enable flakes using traditional configuration before you can use flake-based configs.

### Hardware Configuration Missing

**Error:**
```
error: attribute 'hardware-configuration' missing
```

**Solution:**

Generate hardware configuration:

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Then import it in your `configuration.nix`:

```nix
imports = [ ./hardware-configuration.nix ];
```

### Marchyo Module Not Found

**Error:**
```
error: attribute 'nixosModules' missing
```

**Solution:**

Ensure Marchyo is properly imported in `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo = {
      url = "github:Jylhis/marchyo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        marchyo.nixosModules.default  # ← This line is required
        ./configuration.nix
      ];
    };
  };
}
```

### Input Lock Errors

**Error:**
```
error: cannot find flake 'flake:marchyo' in the flake registries
```

**Solution:**

Update flake lock file:

```bash
nix flake lock --update-input marchyo
# or update all inputs:
nix flake update
```

## Build & Configuration Errors

### Syntax Errors in Nix Files

**Error:**
```
error: syntax error, unexpected '}'
```

**Solution:**

1. Check for missing semicolons, brackets, or quotes
2. Use an editor with Nix syntax highlighting
3. Validate syntax:

```bash
nix-instantiate --parse configuration.nix
```

4. Format code:

```bash
nix fmt
```

### Infinite Recursion

**Error:**
```
error: infinite recursion encountered
```

**Cause:** Circular dependencies in module configuration.

**Solution:**

1. Check for self-referential options
2. Use `mkDefault` or `mkOverride` to break recursion:

```nix
# Instead of:
foo = config.foo;

# Use:
foo = lib.mkDefault someValue;
```

3. Review module imports for circular dependencies

### Evaluation Too Deep

**Error:**
```
error: stack overflow (possible infinite recursion)
```

**Solution:**

Increase evaluation depth (temporary workaround):

```bash
nix build --option max-call-depth 10000
```

Better: Fix the recursive configuration causing the issue.

### Missing Option Errors

**Error:**
```
error: The option `marchyo.users.<name>' is used but not defined
```

**Solution:**

Ensure you've defined required options:

```nix
marchyo.users.username = {
  enable = true;
  fullname = "Your Name";    # Required
  email = "you@example.com";  # Required
};
```

### Type Mismatches

**Error:**
```
error: value is a string while a Boolean was expected
```

**Solution:**

Check option types:

```nix
# Wrong:
marchyo.desktop.enable = "true";

# Correct:
marchyo.desktop.enable = true;
```

## Desktop Environment Issues

### Hyprland Doesn't Start

**Symptoms:** Black screen, immediately returns to login, or crashes.

**Debugging:**

1. Check Hyprland logs:

```bash
journalctl --user -u hyprland -b
```

2. Check display manager logs:

```bash
journalctl -u display-manager -b
```

3. Try starting Hyprland manually from TTY:

```bash
# Switch to TTY with Ctrl+Alt+F2
Hyprland
```

**Common Causes:**

**Missing Graphics Drivers:**

```nix
# Ensure graphics are enabled:
marchyo.desktop.enable = true;

# For NVIDIA:
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia.modesetting.enable = true;
```

**Wayland Not Supported:**

Some older or proprietary graphics drivers don't support Wayland well.

Temporary workaround (use Xorg):

```nix
services.xserver.enable = true;
services.xserver.desktopManager.gnome.enable = true;
```

**Config Syntax Errors:**

Check Hyprland config syntax:

```bash
# View Home Manager hyprland config
home-manager generations | head -1
ls -la $(home-manager generations | head -1 | awk '{print $7}')/home-files/.config/hypr/
```

### Display Manager Not Starting

**Error:** Stuck at boot or console login.

**Solution:**

1. Check display manager status:

```bash
systemctl status display-manager
```

2. View detailed logs:

```bash
journalctl -u display-manager -xe
```

3. Ensure GDM is enabled (Marchyo default):

```nix
marchyo.desktop.enable = true;
# GDM is automatically enabled
```

4. Try different display manager:

```nix
# Disable default and use SDDM instead:
services.xserver.displayManager.gdm.enable = lib.mkForce false;
services.xserver.displayManager.sddm.enable = true;
```

### Screen Tearing or Artifacts

**Solution:**

Enable VSync and configure graphics properly:

```nix
# For Intel:
hardware.graphics.extraPackages = with pkgs; [
  intel-media-driver
  vaapiVdpau
];

# For AMD:
hardware.graphics.extraPackages = with pkgs; [
  rocm-opencl-icd
  amdvlk
];

# In Hyprland config (Home Manager):
wayland.windowManager.hyprland.settings = {
  general = {
    gaps_in = 5;
    gaps_out = 10;
    border_size = 2;
  };
  decoration = {
    blur = {
      enabled = true;
      size = 8;
      passes = 3;
    };
    drop_shadow = true;
    shadow_range = 30;
  };
  animations = {
    enabled = true;
    bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
  };
};
```

### Keyboard Layout Issues

**Problem:** Wrong keyboard layout or keys not working.

**Solution:**

Set keyboard layout in multiple places:

```nix
# Console (before Xorg starts):
console.keyMap = "us";

# Xorg/Wayland:
services.xserver.xkb = {
  layout = "us";
  variant = "";
  options = "ctrl:nocaps";  # Optional: remap caps lock
};

# Hyprland specific:
wayland.windowManager.hyprland.settings = {
  input = {
    kb_layout = "us";
    kb_variant = "";
    kb_options = "ctrl:nocaps";
  };
};
```

### No Sound

**Debugging:**

```bash
# Check if PipeWire is running:
systemctl --user status pipewire pipewire-pulse

# Test audio:
pactl list sinks
speaker-test -c 2 -t wav

# Check volume (might be muted):
pactl set-sink-volume @DEFAULT_SINK@ 50%
pactl set-sink-mute @DEFAULT_SINK@ 0
```

**Solution:**

Ensure audio is enabled (automatic with desktop):

```nix
marchyo.desktop.enable = true;
# Enables PipeWire automatically
```

Manual PipeWire configuration:

```nix
services.pipewire = {
  enable = true;
  alsa.enable = true;
  pulse.enable = true;
  jack.enable = true;
};
```

### Bluetooth Not Working

**Debugging:**

```bash
# Check bluetooth service:
systemctl status bluetooth

# List bluetooth devices:
bluetoothctl devices

# Try pairing:
bluetoothctl
> scan on
> pair XX:XX:XX:XX:XX:XX
```

**Solution:**

Enable bluetooth (automatic with desktop):

```nix
marchyo.desktop.enable = true;
# Enables bluetooth and blueman automatically
```

Manual configuration:

```nix
hardware.bluetooth.enable = true;
services.blueman.enable = true;
```

## Module & Feature Flag Problems

### Feature Flags Not Working

**Problem:** Enabled a feature flag but packages aren't installed.

**Debugging:**

```bash
# Check what's currently installed:
nix-store -q --references /run/current-system | grep -i <package-name>

# Verify feature flag in config:
nix eval .#nixosConfigurations.hostname.config.marchyo.desktop.enable
```

**Solution:**

Ensure proper syntax:

```nix
# Wrong (no effect):
marchyo.desktop = true;
marchyo.development = true;

# Correct:
marchyo.desktop.enable = true;
marchyo.development.enable = true;
```

### Conflicting Module Options

**Error:**
```
error: The option `services.foo.bar' has conflicting definitions
```

**Solution:**

Use priority to resolve conflicts:

```nix
# Override Marchyo's default:
services.someservice.enable = lib.mkForce false;

# Set lower priority (Marchyo wins):
services.someservice.enable = lib.mkDefault true;

# Set higher priority (your config wins):
services.someservice.enable = lib.mkOverride 50 true;
```

Priority levels (lower number = higher priority):
- `mkForce` = 50
- `mkOverride` = custom
- `mkDefault` = 1000

### Module Import Errors

**Error:**
```
error: cannot import <path>. Module does not exist
```

**Solution:**

Check import paths:

```nix
# Relative paths:
imports = [ ./modules/mymodule.nix ];

# From flake inputs:
imports = [ inputs.marchyo.nixosModules.default ];

# Ensure file exists:
ls -la modules/mymodule.nix
```

## Home Manager Issues

### Home Manager Not Activating

**Symptoms:** User configuration not applied, home-manager command fails.

**Solution:**

Ensure Home Manager is properly configured:

```nix
{
  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, marchyo, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        marchyo.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.username = {
              imports = [ marchyo.homeModules.default ];
              home.stateVersion = "24.11";
            };
          };
        }
        ./configuration.nix
      ];
    };
  };
}
```

### Home Manager Build Fails

**Error:**
```
error: collision between <path1> and <path2>
```

**Cause:** Two packages trying to install the same file.

**Solution:**

Use `lib.mkForce` or exclude conflicting packages:

```nix
home.packages = lib.mkForce (with pkgs; [
  # Your specific package list
]);
```

Or use package priorities:

```nix
home.packages = with pkgs; [
  (hiPrio preferredPackage)
  (lowPrio alternativePackage)
];
```

### Config Files Not Updating

**Problem:** Changed home-manager config but files don't update.

**Solution:**

1. Rebuild Home Manager:

```bash
home-manager switch --flake .#username
```

2. Or rebuild entire system (includes Home Manager):

```bash
sudo nixos-rebuild switch --flake .#hostname
```

3. Check activation:

```bash
# View Home Manager generation:
home-manager generations

# Check what would change:
home-manager build --flake .#username
nix store diff-closures ~/.nix-profile ./result
```

### Permission Errors

**Error:**
```
error: cannot create directory '/home/user/.config/foo': Permission denied
```

**Solution:**

Ensure proper ownership:

```bash
sudo chown -R username:users /home/username
```

Or use `systemd.user.services` for system-managed user services:

```nix
systemd.user.services.myservice = {
  Unit.Description = "My Service";
  Service = {
    ExecStart = "${pkgs.mypackage}/bin/myapp";
    Restart = "always";
  };
  Install.WantedBy = [ "default.target" ];
};
```

## System Recovery

### Boot Into Previous Generation

**At boot (GRUB/systemd-boot menu):**

1. Select "NixOS - All configurations"
2. Choose previous generation
3. Boot

**From running system:**

```bash
# List generations:
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to specific generation:
./scripts/rollback.sh <generation-number>

# Or manually:
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

### Rollback After Failed Update

```bash
# Quick rollback:
sudo nixos-rebuild switch --rollback

# Or use script:
./scripts/rollback.sh
```

### System Won't Boot

**From live USB:**

```bash
# Mount system:
sudo mount /dev/disk/by-label/nixos /mnt
sudo mount /dev/disk/by-label/boot /mnt/boot

# Chroot into system:
sudo nixos-enter

# Rollback:
nix-env --rollback --profile /nix/var/nix/profiles/system
/nix/var/nix/profiles/system/bin/switch-to-configuration boot

# Exit and reboot:
exit
sudo reboot
```

### Rescue Shell

If system boots to rescue shell:

```bash
# Check disk mounts:
lsblk
mount

# Check filesystem errors:
sudo fsck /dev/sdXY

# Mount and continue boot:
mount -a
systemctl isolate multi-user.target
```

### Clear Boot Issues

```bash
# Rebuild bootloader:
sudo nixos-rebuild switch --install-bootloader

# Regenerate boot entries:
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
```

## Debugging Tools & Techniques

### Nix Build Debugging

```bash
# Build with detailed output:
nix build --show-trace .#nixosConfigurations.hostname.config.system.build.toplevel

# Keep failed build directory:
nix build --keep-failed

# Inspect failed build:
cd /tmp/nix-build-*
ls -la
```

### Evaluating Nix Expressions

```bash
# Check option value:
nix eval .#nixosConfigurations.hostname.config.marchyo.desktop.enable

# Show all marchyo options:
nix eval .#nixosConfigurations.hostname.config.marchyo --json | jq

# Pretty print:
nix eval .#nixosConfigurations.hostname.config.environment.systemPackages --apply builtins.length
```

### System Logs

```bash
# All errors since boot:
journalctl -b -p err

# Specific service:
journalctl -u servicename -f

# User services:
journalctl --user -u servicename

# Last boot:
journalctl -b -1

# Follow logs in real-time:
journalctl -f
```

### Comparing Generations

```bash
# Using nvd (recommended):
nvd diff /run/booted-system /run/current-system

# Using nix:
nix store diff-closures /run/booted-system /run/current-system

# List what changed:
nix-store -q --references /run/current-system | sort > current.txt
nix-store -q --references /run/booted-system | sort > booted.txt
diff booted.txt current.txt
```

### Memory & Disk Usage

```bash
# Nix store size:
du -sh /nix/store

# Clean old generations:
sudo nix-collect-garbage --delete-older-than 30d

# Optimize store:
nix-store --optimise

# Check what's using space:
nix-store --gc --print-roots | grep -v '/proc/'
```

### Network Debugging

```bash
# Check network status:
networkctl status

# DNS resolution:
resolvectl status

# Connection test:
ping -c 3 nixos.org

# Check firewall:
sudo iptables -L -n -v
```

## Getting Help

### Before Asking for Help

Gather this information:

```bash
# System info:
fastfetch

# Nix version:
nix --version

# Check flake:
nix flake show

# Check current config:
cat /etc/nixos/configuration.nix

# Recent errors:
journalctl -b -p err --no-pager | tail -50
```

### Where to Get Help

1. **Marchyo Issues:** https://github.com/Jylhis/marchyo/issues
2. **NixOS Discourse:** https://discourse.nixos.org
3. **NixOS Reddit:** https://reddit.com/r/NixOS
4. **Matrix/Discord:** NixOS community channels

### Reporting Bugs

Include in your bug report:

1. Marchyo version (git commit or flake input)
2. NixOS version (`nixos-version`)
3. Minimal reproducible configuration
4. Error messages (full output)
5. Steps to reproduce
6. Expected vs actual behavior

Template:

```markdown
## System Information
- NixOS version: <output of nixos-version>
- Marchyo version: <git commit or flake input>

## Configuration
```nix
<minimal configuration that reproduces the issue>
```

## Steps to Reproduce
1. ...
2. ...

## Expected Behavior
...

## Actual Behavior
...

## Error Output
```
<full error message>
```

## Logs
```
<relevant journalctl output>
```
```

## Next Steps

- [Configuration Guide](configuration.md) - Configure Marchyo correctly
- [Module Reference](modules-reference.md) - Understand what modules do
- [Installation Guide](installation.md) - Installation troubleshooting

---

**Still stuck?** Don't hesitate to ask for help on GitHub Issues or NixOS community channels!
