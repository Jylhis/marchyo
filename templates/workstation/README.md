# Marchyo Developer Workstation Template

This is a full-featured developer workstation configuration with desktop environment and comprehensive development tools.

## Quick Start


1. **Initialize your configuration**:
   ```bash
   nix flake init -t github:marchyo/marchyo#workstation
   ```

2. **Generate hardware configuration**:
   ```bash
   nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```

3. **Customize configuration.nix**:
   - Change `networking.hostName` to your workstation name
   - Update `marchyo.users.developer` with your details
   - Adjust timezone and locale settings
   - Review and modify development tools

4. **RUN VM**
```shell
# With disko
nix run -L '.#nixosConfigurations.workstation.config.system.build.vmWithDisko'

# Without
nixos-rebuild build-vm --flake .#workstation
./result/bin/run-workstation-vm
```

4. **Build and switch**:
   ```bash
   sudo nixos-rebuild switch --flake .#workstation
   ```


## Included Features

### Desktop Environment
- Hyprland (Wayland compositor)
- Complete desktop environment with all Marchyo customizations
- Multiple terminal emulators (Kitty, Alacritty)

### Development Tools

#### Editors
- Vim/Neovim
- VS Code

#### Version Control
- Git with Git LFS
- GitHub CLI (gh)

#### Containers
- Docker with docker-compose
- Kubernetes (kubectl)
- Virtualization (QEMU/KVM via libvirtd)

#### DevOps
- Terraform
- Ansible
- Kubernetes CLI

### Terminal Enhancement
- Starship prompt
- Zoxide (smart cd)
- fzf (fuzzy finder)
- ripgrep (fast grep)
- fd (fast find)

## Customization

### Programming Languages

Add your preferred programming languages:

```nix
environment.systemPackages = with pkgs; [
  # Python
  python3
  python3Packages.pip
  python3Packages.virtualenv

  # Node.js
  nodejs
  yarn

  # Rust
  rustc
  cargo

  # Go
  go

  # Java
  jdk17
];
```

### IDE Integration

#### VS Code Extensions

Use Home Manager for VS Code extensions:

```nix
programs.vscode = {
  enable = true;
  extensions = with pkgs.vscode-extensions; [
    ms-python.python
    ms-vscode.cpptools
    rust-lang.rust-analyzer
  ];
};
```

### Database Tools

Add database clients and servers:

```nix
services.postgresql = {
  enable = true;
  package = pkgs.postgresql_15;
};

environment.systemPackages = with pkgs; [
  pgcli
  mysql-client
  redis
  mongodb-compass
];
```

### Container Alternatives

Choose between Docker and Podman:

```nix
# Option 1: Docker (default in template)
virtualisation.docker.enable = true;

# Option 2: Podman (rootless alternative)
virtualisation.podman = {
  enable = true;
  dockerCompat = true;
  defaultNetwork.settings.dns_enabled = true;
};
```

### Custom Development Shells

Create project-specific shells with direnv:

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
};
```

Then in your project directory, create a `.envrc`:

```bash
use flake
```

## Workspace Organization

### Multiple Monitors

Hyprland configuration is in Marchyo modules. Override in your home configuration:

```nix
wayland.windowManager.hyprland.settings = {
  monitor = [
    "DP-1,1920x1080@60,0x0,1"
    "HDMI-A-1,1920x1080@60,1920x0,1"
  ];
};
```

### Productivity Apps

Add productivity applications:

```nix
environment.systemPackages = with pkgs; [
  # Communication
  slack
  discord
  zoom-us

  # Browsers
  firefox
  chromium

  # Note-taking
  obsidian
  joplin-desktop

  # Office
  libreoffice-fresh
  thunderbird
];
```

## Performance Tuning

### SSD Optimization

For systems with SSD:

```nix
services.fstrim.enable = true;
```

### Gaming Performance

If you also game on this workstation:

```nix
programs.gamemode.enable = true;
hardware.opengl = {
  enable = true;
  driSupport = true;
  driSupport32Bit = true;
};
```

## Backup Strategy

Set up automatic backups:

```nix
services.restic.backups.home = {
  paths = [ "/home/developer" ];
  repository = "s3:s3.amazonaws.com/my-backup-bucket";
  passwordFile = "/etc/nixos/secrets/restic-password";
  timerConfig = {
    OnCalendar = "daily";
  };
};
```

## Updating

Update your workstation:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#workstation
```

## Troubleshooting

### Docker Issues

If Docker services fail to start:
```bash
sudo systemctl restart docker
```

### Display Issues

Check Hyprland logs:
```bash
journalctl --user -u hyprland
```

### Performance Monitoring

Monitor system resources:
```bash
btop  # Modern resource monitor
htop  # Classic resource monitor
```

# Run VM

```shell
nix run -L '.#nixosConfigurations.default.config.system.build.vmWithDisko'
```
