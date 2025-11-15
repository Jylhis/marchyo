# Theming System

How Marchyo integrates color schemes across all applications.

## Overview

Marchyo uses [nix-colors](https://github.com/Misterio77/nix-colors) for unified theming, providing:
- 200+ pre-defined color schemes
- Custom Modus themes
- Automatic application configuration
- Consistent colors system-wide

## Theme Architecture

### Color Scheme Sources

```
nix-colors (200+ schemes)
  +
Custom colorschemes (Modus themes)
  ↓
Merged in flake.nix
  ↓
Available as config.colorScheme.palette
  ↓
Used by applications
```

### Integration Points

**Flake Level** (`flake.nix`):
```nix
extraSpecialArgs = {
  colorSchemes = nix-colors.colorSchemes // (import ./colorschemes);
};
```

**Home Manager** (`modules/home/theme.nix`):
```nix
imports = [ nix-colors.homeManagerModules.default ];

colorScheme =
  if cfg.scheme != null then schemes.${cfg.scheme}
  else if cfg.variant == "light" then schemes.modus-operandi-tinted
  else schemes.modus-vivendi-tinted;
```

## Base16 Color System

All themes follow the Base16 specification:

```nix
palette = {
  base00 = "1e1e2e";  # Background
  base01 = "181825";  # Lighter background
  base02 = "313244";  # Selection
  base03 = "45475a";  # Comments
  base04 = "585b70";  # Dark foreground
  base05 = "cdd6f4";  # Foreground
  base06 = "f5e0dc";  # Light foreground
  base07 = "b4befe";  # Lighter foreground
  base08 = "f38ba8";  # Red
  base09 = "fab387";  # Orange
  base0A = "f9e2af";  # Yellow
  base0B = "a6e3a1";  # Green
  base0C = "94e2d5";  # Cyan
  base0D = "89b4fa";  # Blue
  base0E = "cba6f7";  # Purple
  base0F = "f2cdcd";  # Magenta
};
```

## Application Theming

### Kitty Terminal

**Module**: `modules/home/kitty.nix`

```nix
programs.kitty.settings = {
  foreground = "#${colors.base05}";
  background = "#${colors.base00}";

  # 16 ANSI colors
  color0 = "#${colors.base00}";
  color1 = "#${colors.base08}";
  color2 = "#${colors.base0B}";
  # ... through color15

  # Tab bar colors
  active_tab_foreground = "#${colors.base00}";
  active_tab_background = "#${colors.base0D}";
};
```

### Waybar Status Bar

**Module**: `modules/home/waybar.nix`

Generates CSS with color variables:

```nix
style = ''
  * {
    --base00: #${colors.base00};
    --base0D: #${colors.base0D};
    /* ... all colors ... */
  }

  #workspaces button.active {
    background-color: var(--base0D);
  }
'';
```

### Hyprland Window Manager

**Module**: `modules/home/hyprland.nix`

Window border colors:

```nix
general = {
  "col.active_border" = "rgba(${colors.base0D}ff)";
  "col.inactive_border" = "rgba(${colors.base03}ff)";
};
```

### Mako Notifications

**Module**: `modules/home/mako.nix`

```nix
backgroundColor = "#${colors.base00}";
textColor = "#${colors.base05}";
borderColor = "#${colors.base0D}";
```

### Vicinae Launcher

**Module**: `modules/home/vicinae.nix`

Generates TOML theme dynamically:

```nix
xdg.configFile."vicinae/theme.toml".text = ''
  [colors]
  background = "#${colors.base00}"
  foreground = "#${colors.base05}"
  selection = "#${colors.base0D}"
  # ... complete palette mapping
'';
```

### Starship Prompt

**Module**: `modules/home/starship.nix`

```nix
format = lib.concatStrings [
  "[┌─](bold ${colors.base0D})"
  # ... prompt with color codes
];
```

## Color Utilities

**Location**: `lib/colors.nix`

### Hex to Decimal

```nix
hexToDec = hex:
  # "ff" -> 255
```

### RGB Formatting

```nix
toRgb = hex:
  # "ff5533" -> "rgb(255,85,51)"

toRgba = hex: alpha:
  # "ff5533" 0.8 -> "rgba(255,85,51,0.8)"
```

### Hash Prefix

```nix
withHash = color:
  # "ff5533" -> "#ff5533"
```

## Theme Selection Logic

```nix
# In home/theme.nix
colorScheme =
  # User specified a scheme
  if cfg.scheme != null then
    if builtins.isString cfg.scheme then
      schemes.${cfg.scheme}  # Look up by name
    else
      cfg.scheme  # Use custom attrs

  # No scheme, use variant default
  else if cfg.variant == "light" then
    schemes.modus-operandi-tinted
  else
    schemes.modus-vivendi-tinted;
```

## Creating Custom Schemes

### File Structure

**`colorschemes/my-theme.nix`**:
```nix
{
  slug = "my-theme";
  name = "My Theme";
  author = "Your Name";
  variant = "dark";
  palette = {
    base00 = "000000";
    base01 = "111111";
    # ... base02-base0F
  };
}
```

**`colorschemes/default.nix`**:
```nix
{
  modus-vivendi-tinted = import ./modus-vivendi-tinted.nix;
  modus-operandi-tinted = import ./modus-operandi-tinted.nix;
  my-theme = import ./my-theme.nix;  # Add your theme
}
```

### Color Palette Guidelines

1. **Contrast**: Ensure sufficient contrast between foreground/background
2. **Accessibility**: Follow WCAG guidelines (4.5:1 minimum for text)
3. **Consistency**: Use colors for their semantic meaning
4. **Testing**: Test in all themed applications

## Theme Testing

### Quick Test

```bash
# Build without switching
sudo nixos-rebuild build --flake .#hostname

# Test temporarily
sudo nixos-rebuild test --flake .#hostname
```

### Check Colors

```bash
# View current palette
nix eval .#homeConfigurations.user@hostname.config.colorScheme.palette --show-trace
```

### Preview in Applications

1. Kitty: Open terminal, check colors
2. Waybar: Check status bar styling
3. Vicinae: Open launcher (`Super+R`)
4. Mako: Send test notification

## Theme Propagation Timing

1. **System rebuild**: Theme configuration is set
2. **Home Manager activation**:
   - Config files generated with colors
   - Applications restart on next login
3. **Manual restart**: Some apps need manual restart:
   ```bash
   systemctl --user restart waybar
   ```

## Advanced Customization

### Override Individual Colors

```nix
# Use gruvbox but change blue
marchyo.theme.scheme = (schemes.gruvbox-dark-medium) // {
  palette = schemes.gruvbox-dark-medium.palette // {
    base0D = "89b4fa";  # Custom blue
  };
};
```

### Per-Application Color Override

```nix
# Different terminal colors
programs.kitty.settings = {
  background = "#000000";  # Override theme
};
```

### Conditional Theming

```nix
programs.waybar.style =
  if config.colorScheme.variant == "dark" then ''
    /* Dark theme styles */
  '' else ''
    /* Light theme styles */
  '';
```

## Troubleshooting

### Colors Not Applied

1. Check theme is enabled:
   ```nix
   marchyo.theme.enable = true;
   ```

2. Rebuild home-manager:
   ```bash
   home-manager switch --flake .#user@hostname
   ```

3. Restart affected applications

### Wrong Colors

1. Verify color scheme:
   ```bash
   nix eval .#homeConfigurations.user@hostname.config.colorScheme.slug
   ```

2. Check palette values:
   ```bash
   nix eval .#homeConfigurations.user@hostname.config.colorScheme.palette.base0D
   ```

### Application Not Themed

Check if the application has theme support in Marchyo:
- Supported: kitty, waybar, mako, vicinae, hyprland, starship
- Not supported: Add custom configuration

## Resources

- [nix-colors](https://github.com/Misterio77/nix-colors) - Color scheme library
- [Base16](https://github.com/chriskempson/base16) - Color scheme specification
- [Customize Theme Guide](../how-to/customize-theme.md) - Practical customization
- [Color Schemes Reference](../reference/color-schemes.md) - Available schemes
