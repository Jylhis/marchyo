# Color Schemes

Available color schemes in Marchyo.

## Custom Marchyo Schemes

### Modus Vivendi Tinted (Dark)

Professional dark theme by Protesilaos Stavrou.

```nix
marchyo.theme.scheme = "modus-vivendi-tinted";
```

### Modus Operandi Tinted (Light)

Professional light theme by Protesilaos Stavrou.

```nix
marchyo.theme.scheme = "modus-operandi-tinted";
```

## Popular nix-colors Schemes

### Dark Themes

- **`dracula`** - Dracula
- **`gruvbox-dark-medium`** - Gruvbox Dark Medium
- **`catppuccin-mocha`** - Catppuccin Mocha
- **`nord`** - Nord
- **`tokyo-night-dark`** - Tokyo Night Dark
- **`onedark`** - One Dark
- **`solarized-dark`** - Solarized Dark
- **`moonfly`** - Moonfly
- **`oceanic-next`** - Oceanic Next
- **`tomorrow-night`** - Tomorrow Night

### Light Themes

- **`catppuccin-latte`** - Catppuccin Latte
- **`gruvbox-light-medium`** - Gruvbox Light Medium
- **`solarized-light`** - Solarized Light
- **`tokyo-night-light`** - Tokyo Night Light
- **`github`** - GitHub
- **`tomorrow`** - Tomorrow

## Complete nix-colors List

Over 200 schemes available from the [base16 project](https://github.com/tinted-theming/schemes).

Browse all schemes: [nix-colors repository](https://github.com/Misterio77/nix-colors)

## Using a Scheme

```nix
marchyo.theme = {
  enable = true;
  scheme = "dracula";  # Use scheme name
};
```

## Creating Custom Schemes

See [Customize Theme](../how-to/customize-theme.md) for detailed instructions.

## Base16 Colors

All schemes follow the Base16 specification:

| Color | Typical Use |
|-------|-------------|
| base00 | Default Background |
| base01 | Lighter Background |
| base02 | Selection Background |
| base03 | Comments, Invisibles |
| base04 | Dark Foreground |
| base05 | Default Foreground |
| base06 | Light Foreground |
| base07 | Lighter Foreground |
| base08 | Red |
| base09 | Orange |
| base0A | Yellow |
| base0B | Green |
| base0C | Cyan |
| base0D | Blue |
| base0E | Purple |
| base0F | Magenta/Pink |

## Themed Applications

- Kitty (terminal)
- Waybar (status bar)
- Mako (notifications)
- Vicinae (launcher)
- Hyprland (window borders)
- Starship (prompt)

## Resources

- [Base16 Project](https://github.com/chriskempson/base16)
- [nix-colors](https://github.com/Misterio77/nix-colors)
- [Customize Theme Guide](../how-to/customize-theme.md)
