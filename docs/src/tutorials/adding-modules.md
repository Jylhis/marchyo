# Adding Modules

Learn how to extend your NixOS configuration with additional modules.

## What are NixOS Modules?

NixOS modules are the building blocks of your system configuration. They define:
- Configuration options
- Services
- Package installations
- System behavior

Marchyo is built entirely from NixOS modules organized into three categories:
- **NixOS modules** - System-level configuration
- **Home Manager modules** - User environment configuration
- **Generic modules** - Shared between NixOS and Home Manager

## Using Marchyo's Modules

Marchyo's modules are automatically imported when you add `marchyo.nixosModules.default` to your configuration.

### Example: Enabling Desktop Module

```nix
{
  marchyo.desktop.enable = true;
}
```

This single line enables:
- Hyprland window manager
- Audio (PipeWire)
- Bluetooth
- Fonts
- Printing
- And more

See [NixOS Module Options](../reference/modules/nixos-options.md) for all available `marchyo.*` options.

## Adding External Modules

You can add modules from other flakes or your own custom modules.

### Adding a Flake Module

Example: Adding `disko` for disk partitioning:

**Edit `flake.nix`:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    marchyo.url = "github:Jylhis/marchyo";

    # Add disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, marchyo, disko, ... }: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        marchyo.nixosModules.default
        disko.nixosModules.disko  # Add the module
        ./hardware-configuration.nix
        ./configuration.nix
      ];
    };
  };
}
```

Then update your flake lock:

```bash
nix flake update
```

### Adding a Local Module

Create a custom module file:

**`/etc/nixos/modules/custom-app.nix`:**

```nix
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.myapp;
in {
  options.myapp = {
    enable = mkEnableOption "my custom application";

    package = mkOption {
      type = types.package;
      default = pkgs.myapp;
      description = "The package to use for myapp";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Add configuration here
  };
}
```

**Import in `configuration.nix`:**

```nix
{
  imports = [
    ./modules/custom-app.nix
  ];

  myapp.enable = true;
}
```

## Creating Home Manager Modules

Home Manager modules configure user-specific settings.

**`/etc/nixos/modules/home/my-app.nix`:**

```nix
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.myapp;
in {
  options.programs.myapp = {
    enable = mkEnableOption "myapp";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.myapp ];

    # User-specific config
    home.file.".config/myapp/config.toml".text = ''
      # Configuration here
    '';
  };
}
```

**Import in home-manager configuration:**

```nix
{
  home-manager.users.myuser = {
    imports = [
      ./modules/home/my-app.nix
    ];

    programs.myapp.enable = true;
  };
}
```

## Module Organization Best Practices

### Directory Structure

```
/etc/nixos/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
└── modules/
    ├── nixos/           # System-level modules
    │   ├── gaming.nix
    │   └── work.nix
    └── home/            # User-level modules
        ├── neovim.nix
        └── tmux.nix
```

### Module Template

```nix
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.mymodule;
in {
  # Options definition
  options.mymodule = {
    enable = mkEnableOption "my module";

    option1 = mkOption {
      type = types.str;
      default = "default value";
      description = "Description of option1";
    };
  };

  # Configuration
  config = mkIf cfg.enable {
    # Your config here
  };
}
```

## Common Module Patterns

### Conditional Package Installation

```nix
config = mkIf cfg.enable {
  environment.systemPackages = with pkgs; [
    package1
    package2
  ] ++ lib.optionals cfg.extraFeature [
    package3
    package4
  ];
};
```

### Service Configuration

```nix
config = mkIf cfg.enable {
  systemd.services.myservice = {
    description = "My Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.myapp}/bin/myapp";
      Restart = "always";
    };
  };
};
```

### File Generation

```nix
config = mkIf cfg.enable {
  environment.etc."myapp/config.conf".text = ''
    setting1 = ${cfg.setting1}
    setting2 = ${toString cfg.setting2}
  '';
};
```

## Testing Your Module

```bash
# Check syntax
nix eval .#nixosConfigurations.myhostname.config.mymodule --show-trace

# Build without switching
sudo nixos-rebuild build --flake /etc/nixos#myhostname

# Test configuration (reverts on reboot)
sudo nixos-rebuild test --flake /etc/nixos#myhostname
```

## Example: Gaming Module

Here's a complete example of a gaming module:

**`/etc/nixos/modules/gaming.nix`:**

```nix
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.gaming;
in {
  options.gaming = {
    enable = mkEnableOption "gaming configuration";

    steam.enable = mkEnableOption "Steam";
    lutris.enable = mkEnableOption "Lutris";
  };

  config = mkIf cfg.enable {
    # Enable 32-bit graphics drivers
    hardware.opengl.driSupport32Bit = true;

    # Install gaming packages
    environment.systemPackages = with pkgs; [
      # Common tools
      gamemode
      mangohud
    ] ++ lib.optionals cfg.steam.enable [
      steam
    ] ++ lib.optionals cfg.lutris.enable [
      lutris
      wine
      winetricks
    ];

    # Enable Steam
    programs.steam.enable = cfg.steam.enable;

    # Performance tweaks
    boot.kernel.sysctl = {
      "vm.max_map_count" = 2147483642;
    };
  };
}
```

**Usage:**

```nix
{
  imports = [
    ./modules/gaming.nix
  ];

  gaming = {
    enable = true;
    steam.enable = true;
    lutris.enable = true;
  };
}
```

## Next Steps

- [Module System Explanation](../explanation/module-system.md) - Deep dive into how modules work
- [NixOS Module Options](../reference/modules/nixos-options.md) - Reference for all Marchyo options
- [Troubleshooting](../how-to/troubleshooting.md) - Solving module-related issues

## Resources

- [NixOS Manual - Modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [NixOS Wiki - Modules](https://nixos.wiki/wiki/NixOS_modules)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
