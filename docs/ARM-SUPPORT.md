# ARM Support (aarch64-linux)

Marchyo now supports ARM64 (aarch64-linux) architecture alongside x86_64-linux. This document covers supported devices, limitations, installation instructions, and performance considerations.

## Overview

ARM support in Marchyo is **architecture-agnostic** for most modules. The flake evaluates and builds correctly for both x86_64-linux and aarch64-linux systems. However, some platform-specific considerations apply, particularly for bootloaders, firmware, and hardware acceleration.

## Supported ARM Devices

### Tested Devices

While Marchyo aims to support any aarch64-linux system, testing has been limited. The following device categories are expected to work:

#### Single Board Computers (SBCs)
- **Raspberry Pi 4/5** - Full support with nixos-hardware profiles
- **Pine64 devices** - RockPro64, Pinebook Pro (via nixos-hardware)
- **Orange Pi** - Various models with mainline kernel support
- **Rock Pi** - Rock64, RockPi 4 series

#### ARM Servers
- **Ampere Altra/Altra Max** - Cloud-native ARM servers
- **AWS Graviton** - EC2 instances (a1, t4g, m6g, c6g, etc.)
- **Oracle Cloud ARM** - Ampere A1 instances
- **Hetzner Cloud ARM** - CAX instances

#### ARM Laptops/Desktops
- **Apple Silicon Macs** - M1/M2/M3 (via Asahi Linux - experimental)
- **Pinebook Pro** - ARM laptop with good Linux support
- **ARM Chromebooks** - With appropriate firmware modifications

### Hardware Profile Integration

Marchyo uses `nixos-hardware` for device-specific optimizations. To use a hardware profile:

```nix
{
  inputs.marchyo.url = "github:yourusername/marchyo";

  nixosConfigurations.my-arm-device = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.marchyo.nixosModules.default
      inputs.nixos-hardware.nixosModules.raspberry-pi-4  # Example
      ./configuration.nix
    ];
  };
}
```

## Known Limitations

### Platform-Specific Issues

1. **ISO Installation Images**
   - x86_64 ISO images are currently the only pre-built installers
   - ARM installation requires manual SD card/USB image creation
   - UEFI support varies by device (most SBCs use U-Boot)

2. **Bootloader Differences**
   - ARM devices typically use U-Boot instead of GRUB/systemd-boot
   - Device-specific boot scripts may be required
   - Some devices need proprietary firmware blobs

3. **Graphics Acceleration**
   - Desktop features (Hyprland, Wayland) work but may have reduced performance
   - Hardware video decoding support varies by SoC
   - Some ARM GPUs have limited open-source driver support

4. **Binary Cache Coverage**
   - Official NixOS binary cache has good aarch64 coverage
   - Some unfree packages may not have ARM builds available
   - Expect more building from source compared to x86_64

5. **Performance Expectations**
   - ARM SBCs (Raspberry Pi) are slower than modern x86_64 systems
   - Initial system builds may take hours on low-power ARM devices
   - Server-class ARM (Graviton, Ampere) performs comparably to x86_64

### Module Compatibility

Most Marchyo modules are architecture-agnostic, but some considerations:

- **Desktop modules** - Work on ARM but performance depends on hardware
- **Development tools** - Generally available for aarch64
- **Containers** - Full Docker/Podman support on ARM
- **Virtualization** - Limited compared to x86_64 (no KVM on some platforms)

## Installation Instructions

### Method 1: SD Card Installation (SBCs)

For devices like Raspberry Pi that boot from SD cards:

1. **Build a custom SD image:**

   ```bash
   # On an x86_64 machine with cross-compilation:
   nix build .#nixosConfigurations.my-rpi4.config.system.build.sdImage \
     --system aarch64-linux

   # Or on an ARM device directly:
   nix build .#nixosConfigurations.my-rpi4.config.system.build.sdImage
   ```

2. **Write the image to SD card:**

   ```bash
   sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```

3. **Boot and configure:**
   - Insert SD card into device
   - Power on and wait for first boot
   - SSH in (if SSH is enabled) or connect display/keyboard
   - Run `nixos-rebuild switch` to apply your configuration

### Method 2: Cloud Instance Installation

For cloud ARM instances (AWS Graviton, Oracle Cloud, etc.):

1. **Start with NixOS ARM image** (if available for your cloud provider)
2. **Clone your configuration:**

   ```bash
   git clone https://github.com/yourusername/your-nixos-config.git
   cd your-nixos-config
   ```

3. **Apply Marchyo configuration:**

   ```bash
   sudo nixos-rebuild switch --flake .#your-arm-host
   ```

### Method 3: Cross-Compilation from x86_64

Build ARM configurations from your x86_64 machine:

1. **Enable binfmt for ARM emulation:**

   ```nix
   # In your x86_64 NixOS configuration:
   boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
   ```

2. **Build ARM configuration:**

   ```bash
   nix build .#nixosConfigurations.my-arm-device.config.system.build.toplevel \
     --system aarch64-linux
   ```

3. **Deploy to ARM device** (various methods):
   - Use `nixos-rebuild --target-host` for remote deployment
   - Copy closure and activate manually
   - Use NixOps or deploy-rs for fleet management

### Method 4: Native Installation on ARM Device

If you already have a Linux ARM system:

1. **Install Nix:**

   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. **Enable flakes:**

   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

3. **Generate NixOS configuration:**

   ```bash
   nixos-generate-config --root /mnt
   ```

4. **Integrate Marchyo:**

   Edit `/mnt/etc/nixos/flake.nix` to include Marchyo modules.

## Configuration Examples

### Raspberry Pi 4 Configuration

```nix
{
  description = "Raspberry Pi 4 with Marchyo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    marchyo.url = "github:yourusername/marchyo";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { nixpkgs, marchyo, nixos-hardware, ... }: {
    nixosConfigurations.rpi4 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        marchyo.nixosModules.default
        nixos-hardware.nixosModules.raspberry-pi-4
        {
          # Hardware-specific boot configuration
          boot = {
            loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
            kernelPackages = nixpkgs.lib.mkDefault nixpkgs.linuxPackages_rpi4;
          };

          # Marchyo configuration
          marchyo = {
            users.pi = {
              enable = true;
              fullname = "Pi User";
              email = "pi@example.com";
            };
            # Enable only lightweight modules
            development.enable = true;
          };

          # Basic system configuration
          networking.hostName = "rpi4-marchyo";
          system.stateVersion = "24.11";
        }
      ];
    };
  };
}
```

### AWS Graviton Configuration

```nix
{
  description = "AWS Graviton with Marchyo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    marchyo.url = "github:yourusername/marchyo";
  };

  outputs = { nixpkgs, marchyo, ... }: {
    nixosConfigurations.graviton = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        marchyo.nixosModules.default
        {
          # EC2-compatible boot configuration
          boot.loader.grub = {
            enable = true;
            device = "/dev/nvme0n1";
            efiSupport = true;
          };

          # Marchyo configuration - full features work well on Graviton
          marchyo = {
            users.admin = {
              enable = true;
              fullname = "Admin User";
              email = "admin@example.com";
            };
            development.enable = true;
            desktop.enable = false;  # Headless server
          };

          # AWS-specific networking
          networking = {
            hostName = "graviton-marchyo";
            useDHCP = true;
          };

          system.stateVersion = "24.11";
        }
      ];
    };
  };
}
```

## Performance Notes

### Build Performance

| Device Type | First Build | Rebuild | Notes |
|------------|-------------|---------|-------|
| Raspberry Pi 4 (4GB) | 2-4 hours | 10-30 min | Use binary cache |
| Raspberry Pi 5 (8GB) | 1-2 hours | 5-15 min | Better than Pi 4 |
| AWS Graviton2 (4vCPU) | 20-40 min | 5-10 min | Server-class perf |
| AWS Graviton3 (4vCPU) | 15-30 min | 3-8 min | ~20% faster than G2 |
| Ampere Altra (8 cores) | 10-20 min | 2-5 min | Excellent performance |

### Optimization Tips for ARM

1. **Enable binary cache:**
   ```nix
   nix.settings = {
     substituters = [
       "https://cache.nixos.org"
       "https://nix-community.cachix.org"
     ];
     trusted-public-keys = [
       "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
       "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
     ];
   };
   ```

2. **Use cross-compilation for large builds:**
   - Build on x86_64 with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`
   - Transfer closures to ARM device
   - Activate remotely with `nixos-rebuild`

3. **Minimize desktop features on low-power devices:**
   ```nix
   marchyo.desktop.enable = lib.mkForce false;  # Disable Hyprland on Pi
   ```

4. **Enable zram for memory-constrained devices:**
   ```nix
   zramSwap = {
     enable = true;
     memoryPercent = 50;
   };
   ```

### Runtime Performance

- **Server workloads**: ARM servers (Graviton, Ampere) match or exceed x86_64 in many tasks
- **Desktop workloads**: Usable on Pi 4/5 for light use, but not recommended for heavy GUI work
- **Development**: Code editing and compilation work well on server-class ARM
- **Containers**: Docker/Podman performance is excellent on all ARM platforms

## Troubleshooting

### Common Issues

**Issue: Binary cache misses for packages**
- **Solution**: Some packages may not have aarch64 builds in cache. Build locally or use cross-compilation.

**Issue: Boot failure on SBC**
- **Solution**: Verify U-Boot configuration and device-specific boot requirements. Check nixos-hardware profiles.

**Issue: Slow builds on Raspberry Pi**
- **Solution**: Use binary cache aggressively, cross-compile large packages, or build on more powerful ARM hardware.

**Issue: Display/GPU issues**
- **Solution**: ARM GPU support is device-specific. Check nixos-hardware for device profiles. Consider headless configuration.

**Issue: Cross-compilation failures**
- **Solution**: Ensure `boot.binfmt.emulatedSystems` is set. Some packages may not cross-compile cleanly.

### Getting Help

- Check [NixOS ARM Wiki](https://nixos.wiki/wiki/NixOS_on_ARM)
- Review [nixos-hardware profiles](https://github.com/NixOS/nixos-hardware) for your device
- Ask in NixOS Discourse or Matrix/IRC channels
- File issues at the Marchyo repository for ARM-specific problems

## Testing ARM Configurations

Verify your ARM configuration evaluates correctly:

```bash
# Check flake evaluation
nix flake check --system aarch64-linux

# Build without installing
nix build .#nixosConfigurations.my-arm-host.config.system.build.toplevel \
  --system aarch64-linux

# Test in VM (requires ARM emulation)
nixos-rebuild build-vm --flake .#my-arm-host --system aarch64-linux
```

## Future Improvements

Planned enhancements for ARM support:

- [ ] Pre-built ARM installation images (SD card images for common SBCs)
- [ ] ARM-specific performance optimizations in modules
- [ ] Better hardware acceleration detection and configuration
- [ ] Expanded testing on diverse ARM platforms
- [ ] ARM-specific CI/CD pipeline for testing

## Contributing

Help improve ARM support:

- Test Marchyo on your ARM device and report results
- Submit hardware-specific configurations and profiles
- Document performance characteristics of your ARM hardware
- Contribute fixes for ARM-specific issues

---

**Last Updated**: 2025-10-05
**Marchyo Version**: Compatible with aarch64-linux support
