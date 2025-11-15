# Customize Theme

Learn how to customize Marchyo's color scheme and theming system.

## Changing Color Schemes

Marchyo integrates with nix-colors, providing 200+ color schemes plus custom Modus themes.

### Quick Theme Change

Edit your `configuration.nix`:

```nix
marchyo.theme = {
  enable = true;
  variant = "dark";  # or "light"
  scheme = "dracula";  # scheme name
};
```

Rebuild:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#myhostname
```

### Available Schemes

**Custom Marchyo schemes:**
- `modus-vivendi-tinted` - Professional dark theme
- `modus-operandi-tinted` - Professional light theme

**Popular nix-colors schemes:**
- `dracula` - Dracula theme
- `gruvbox-dark-medium` - Gruvbox Dark
- `catppuccin-mocha` - Catppuccin Mocha
- `catppuccin-latte` - Catppuccin Latte (light)
- `nord` - Nord theme
- `tokyo-night-dark` - Tokyo Night Dark
- `tokyo-night-light` - Tokyo Night Light
- `onedark` - One Dark
- `solarized-dark` - Solarized Dark
- `solarized-light` - Solarized Light

See the complete list: [nix-colors schemes](https://github.com/tinted-theming/schemes)

## Creating a Custom Color Scheme

### Method 1: Inline Definition

Define your scheme directly in `configuration.nix`:

```nix
marchyo.theme = {
  enable = true;
  scheme = {
    slug = "my-theme";
    name = "My Custom Theme";
    author = "Your Name";
    variant = "dark";  # or "light"
    palette = {
      base00 = "1e1e2e";  # Background
      base01 = "181825";  # Lighter background
      base02 = "313244";  # Selection background
      base03 = "45475a";  # Comments, invisibles
      base04 = "585b70";  # Dark foreground
      base05 = "cdd6f4";  # Default foreground
      base06 = "f5e0dc";  # Light foreground
      base07 = "b4befe";  # Lighter foreground
      base08 = "f38ba8";  # Red
      base09 = "fab387";  # Orange
      base0A = "f9e2af";  # Yellow
      base0B = "a6e3a1";  # Green
      base0C = "94e2d5";  # Cyan
      base0D = "89b4fa";  # Blue
      base0E = "cba6f7";  # Purple
      base0F = "f2cdcd";  # Magenta/Pink
    };
  };
};
```

### Method 2: Create a File

Create `/etc/nixos/colorschemes/my-theme.nix`:

```nix
{
  slug = "my-theme";
  name = "My Custom Theme";
  author = "Your Name";
  variant = "dark";
  palette = {
    # ... your colors
  };
}
```

Use it:

```nix
{
  marchyo.theme = {
    enable = true;
    scheme = import ./colorschemes/my-theme.nix;
  };
}
```

## Base16 Color Palette

The Base16 system uses 16 colors:

| Color   | Purpose | Example Use |
|---------|---------|-------------|
| base00  | Background | Editor background |
| base01  | Lighter background | Statusline background |
| base02  | Selection | Selected text background |
| base03  | Comments | Code comments |
| base04  | Dark foreground | Statusline text |
| base05  | Foreground | Default text |
| base06  | Light foreground | - |
| base07  | Lighter foreground | - |
| base08  | Red | Errors, deletion |
| base09  | Orange | Numbers, constants |
| base0A  | Yellow | Warnings, classes |
| base0B  | Green | Strings, addition |
| base0C  | Cyan | Escape characters, regex |
| base0D  | Blue | Functions, links |
| base0E  | Purple | Keywords, tags |
| base0F  | Magenta | Special |

## Themed Applications

Marchyo automatically themes these applications:

- **Terminal**: Kitty
- **Status bar**: Waybar
- **Notifications**: Mako
- **Launcher**: Vicinae
- **Window manager**: Hyprland (window borders)
- **Shell prompt**: Starship

## Per-Application Customization

### Kitty Terminal

Override kitty colors:

```nix
home-manager.users.myuser = {
  programs.kitty.settings = {
    # Override specific colors
    foreground = "#your-color";
    background = "#your-color";
    color0 = "#your-color";
    # ... color1 through color15
  };
};
```

### Waybar

Custom waybar styling:

```nix
home-manager.users.myuser = {
  programs.waybar.style = ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
    }

    window#waybar {
      background-color: #${config.colorScheme.palette.base00};
      color: #${config.colorScheme.palette.base05};
    }

    /* ... more custom CSS ... */
  '';
};
```

### Hyprland

Customize window border colors:

```nix
home-manager.users.myuser = {
  wayland.windowManager.hyprland.settings = {
    general = {
      "col.active_border" = "rgb(${config.colorScheme.palette.base0D})";
      "col.inactive_border" = "rgb(${config.colorScheme.palette.base03})";
    };
  };
};
```

## Testing Themes

To preview themes quickly without rebuilding:

```bash
# Build without switching
sudo nixos-rebuild build --flake /etc/nixos#myhostname

# Test temporarily (reverts on reboot)
sudo nixos-rebuild test --flake /etc/nixos#myhostname
```

## Theme Variants

Switch between light and dark variants:

```nix
# Dark theme (default)
marchyo.theme.variant = "dark";

# Light theme
marchyo.theme.variant = "light";
```

When variant is set but no scheme is specified, Marchyo uses:
- **Dark**: `modus-vivendi-tinted`
- **Light**: `modus-operandi-tinted`

## Troubleshooting

### Theme Not Applied

1. Ensure theme is enabled:
   ```nix
   marchyo.theme.enable = true;
   ```

2. Check that applications are restarted after rebuild

3. For Home Manager changes, rebuild with:
   ```bash
   home-manager switch --flake /etc/nixos#myuser@myhostname
   ```

### Colors Look Wrong

Some terminals/applications may not support true color. Check:

```bash
# Test terminal color support
echo $COLORTERM  # Should show "truecolor" or "24bit"
```

Enable true color in kitty (should be default):

```nix
programs.kitty.settings.term = "xterm-256color";
```

## Resources

- [nix-colors documentation](https://github.com/Misterio77/nix-colors)
- [Base16 specification](https://github.com/chriskempson/base16)
- [Terminal.sexy](https://terminal.sexy/) - Theme generator
- [Coolors.co](https://coolors.co/) - Color palette generator
