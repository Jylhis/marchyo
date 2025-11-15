# Configure Desktop

Customize your Hyprland desktop environment.

## Keybindings

Marchyo provides comprehensive default keybindings. Override them in your home-manager config:

```nix
home-manager.users.myuser = {
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, T, exec, kitty"  # Change terminal keybind
      "SUPER, Q, killactive"    # Custom close window
      # Add your bindings
    ];
  };
};
```

### Default Keybindings

| Key | Action |
|-----|--------|
| `Super + Return` | Open terminal (kitty) |
| `Super + F` | File manager (nautilus) |
| `Super + B` | Browser (brave) |
| `Super + M` | Music (spotify) |
| `Super + R` | Launcher (vicinae) |
| `Super + L` | Lock screen |
| `Super + W` | Close window |
| `Super + J` | Toggle split |
| `Super + V` | Toggle floating |
| `Super + P` | Toggle pseudo-tile |
| `Super + 1-9` | Switch workspace |
| `Super + Shift + 1-9` | Move to workspace |
| `Alt + Tab` | Cycle windows |

## Window Rules

Add custom window rules:

```nix
wayland.windowManager.hyprland.settings = {
  windowrulev2 = [
    "float,class:(my-app)"
    "size 800 600,class:(my-app)"
    "center,class:(my-app)"
  ];
};
```

## Startup Applications

Add applications to auto-start:

```nix
wayland.windowManager.hyprland.settings = {
  exec-once = [
    "discord"
    "element-desktop"
    # Your apps
  ];
};
```

## Monitor Configuration

Configure multiple monitors with kanshi. Create `/etc/nixos/modules/monitors.nix`:

```nix
{ config, ... }:

{
  services.kanshi = {
    enable = true;
    profiles = {
      undocked = {
        outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
          }
        ];
      };
      docked = {
        outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "DP-1";
            mode = "3840x2160@60Hz";
            position = "0,0";
          }
        ];
      };
    };
  };
}
```

## Wallpaper

Change wallpaper:

```nix
services.hyprpaper = {
  enable = true;
  settings = {
    preload = [ "/path/to/wallpaper.png" ];
    wallpaper = [ ",/path/to/wallpaper.png" ];
  };
};
```

## Default Applications

Override default applications in `hyprland.nix`:

```nix
wayland.windowManager.hyprland.settings = {
  "$terminal" = "alacritty";  # Instead of kitty
  "$browser" = "firefox";      # Instead of brave
};
```

## Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
