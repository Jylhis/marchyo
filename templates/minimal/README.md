# Marchyo Minimal Server Template

This is a minimal server configuration without a desktop environment, optimized for servers and headless systems.

## Quick Start

1. **Initialize your configuration**:
   ```bash
   nix flake init -t github:marchyo/marchyo#minimal
   ```

2. **Generate hardware configuration**:
   ```bash
   nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```

3. **Customize configuration.nix**:
   - Change `networking.hostName` to your server name
   - Update `marchyo.users.admin` with your admin details
   - Configure SSH keys for secure access
   - Adjust timezone settings

4. **Build and switch**:
   ```bash
   sudo nixos-rebuild switch --flake .#my-server
   ```

## Security Considerations

### SSH Key Authentication

This template disables password authentication for SSH. Before deploying, add your SSH public key:

```nix
users.users.admin.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3... your-key-here"
];
```

### Firewall

The firewall is enabled by default with only SSH port 22 open. Add more ports as needed:

```nix
networking.firewall.allowedTCPPorts = [ 22 80 443 ];
```

## Server Features

### Automatic Updates

Enable automatic system updates:

```nix
system.autoUpgrade = {
  enable = true;
  flake = "/etc/nixos";
  flags = [
    "--update-input" "nixpkgs"
    "--commit-lock-file"
  ];
};
```

### Monitoring

Add basic monitoring tools:

```nix
environment.systemPackages = with pkgs; [
  htop
  iotop
  nethogs
  sysstat
];
```

### Web Server

Example nginx configuration:

```nix
services.nginx = {
  enable = true;
  virtualHosts."example.com" = {
    locations."/" = {
      root = "/var/www/example.com";
    };
  };
};

networking.firewall.allowedTCPPorts = [ 80 443 ];
```

## Customization

### Add More Services

Check available NixOS services at [NixOS Options Search](https://search.nixos.org/options).

### Container Support

Enable Docker or Podman:

```nix
virtualisation.docker.enable = true;
# or
virtualisation.podman.enable = true;
```

## Updating

Update your server:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#my-server
```

## Maintenance

Regular maintenance tasks:

- Check logs: `journalctl -xe`
- Monitor disk usage: `df -h`
- View running services: `systemctl list-units`
- Clean old generations: `nix-collect-garbage -d`
